import { prisma } from "../../db";
import { decimalToNumber } from "../utils/decimal";
import {
  computeOwedAndBalances,
  computePersonSubtotals,
  round2,
} from "../utils/billmath";
import { minCashFlow, type Transfer } from "../utils/mincashflow";
import { parseReceiptText } from "../utils/ocr";
import { broadcast } from "../utils/broker";
import { UserStatsService } from "../users/service";
import { uploadImage } from "../utils/storage";
import type {
  BillCreateRequest,
  BillFinalizeRequest,
  BillItemAssignmentsRequest,
  BillItemsRequest,
  BillItemUpdateRequest,
  BillMemberCreateRequest,
  BillPatchRequest,
} from "./model";

const letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const numbers = "0123456789";
const inviteCodePattern = /^[A-Z]{3}\d{5}$/;

const randomText = (source: string, length: number) =>
  Array.from(
    { length },
    () => source[Math.floor(Math.random() * source.length)],
  ).join("");

const generateInviteCode = () =>
  `${randomText(letters, 3)}${randomText(numbers, 5)}`;

const isInviteCodeValid = (code?: string | null) =>
  code !== undefined && code !== null && inviteCodePattern.test(code);

const createInviteCode = async () => {
  for (let i = 0; i < 10; i++) {
    const code = generateInviteCode();
    const exists = await prisma.bills.findUnique({
      where: { invite_code: code },
    });

    if (!exists) return code;
  }

  throw new Error("INVITE_CODE_FAILED");
};

const serializeBill = (bill: any) => ({
  ...bill,
  paid_by: (bill.paid_by === null || bill.paid_by === undefined || bill.paid_by === 'null') ? null : bill.paid_by,
  service_charge_pct: decimalToNumber(bill.service_charge_pct),
  vat_pct: decimalToNumber(bill.vat_pct),
});

const serializeItem = (item: any) => ({
  ...item,
  unit_price: decimalToNumber(item.unit_price),
});

export class BillService {
  static async assertMember(userid: string, billId: string) {
    const member = await prisma.billMembers.findUnique({
      where: { bill_id_user_id: { bill_id: billId, user_id: userid } },
    });
    if (!member) throw new Error("FORBIDDEN");
    return member;
  }

  static async assertOwner(userid: string, billId: string) {
    const bill = await prisma.bills.findUnique({ where: { id: billId } });
    if (!bill) throw new Error("NOT_FOUND");
    if (bill.created_by !== userid) throw new Error("FORBIDDEN");
    return bill;
  }

  static async listBills(userid?: string | null) {
    const bills = await prisma.bills.findMany({
      where: userid ? { bill_members: { some: { user_id: userid } } } : undefined,
      include: { _count: { select: { bill_members: true } } },
      orderBy: { created_at: "desc" },
    });

    return bills.map((bill) => ({
      ...serializeBill(bill),
      member_count: bill._count.bill_members,
    }));
  }

  static async getBill(userid: string, billId: string) {
    await this.assertMember(userid, billId);

    const bill = await prisma.bills.findUnique({
      where: { id: billId },
      include: {
        bill_items: {
          include: { item_assigns: true },
          orderBy: { created_at: "asc" },
        },
        bill_members: {
          include: {
            user: {
              select: {
                id: true,
                email: true,
                display_name: true,
                avatar_url: true,
                promptpay_number: true,
              },
            },
          },
        },
      },
    });

    if (!bill) throw new Error("NOT_FOUND");

    const memberIds = new Set(bill.bill_members.map((member) => member.user_id));
    const paidBy = bill.paid_by && memberIds.has(bill.paid_by) ? bill.paid_by : null;
    const serialized = serializeBill({
      ...bill,
      paid_by: paidBy,
      bill_items: undefined,
      bill_members: undefined,
    });

    return {
      bill: serialized,
      items: bill.bill_items.map((item) => ({
        ...serializeItem(item),
        item_assigns: item.item_assigns,
      })),
      members: bill.bill_members.map((m) => ({
        bill_id: m.bill_id,
        user_id: m.user_id,
        role: m.role,
        joined_at: m.joined_at,
        user: m.user,
      })),
      assigns: bill.bill_items.flatMap((i) => i.item_assigns),
    };
  }

  static async createBill(userid: string, data: BillCreateRequest) {
    const bill = await prisma.bills.create({
      data: {
        created_by: userid,
        // paid_by starts as null — set later via PATCH /bills/:id/payer
        name: data.name,
        date: new Date(data.date),
        vat_pct: data.vat_pct ?? 0,
        service_charge_pct: data.service_charge_pct ?? 0,
        status: "active",
        invite_code: await createInviteCode(),
        bill_members: {
          create: { user_id: userid, role: "owner" },
        },
      },
    });
    UserStatsService.onBillCreated(userid).catch(console.error);
    return serializeBill(bill);
  }

  static async addMember(userid: string, billId: string, data: BillMemberCreateRequest) {
    await this.assertMember(userid, billId);

    const existingMembers = await prisma.billMembers.findMany({
      where: { bill_id: billId },
      include: { user: { select: { display_name: true } } },
    });
    const existingNames = new Set(
      existingMembers
        .map((member) => member.user.display_name?.trim().toUpperCase())
        .filter(Boolean),
    );
    const requestedName = data.name?.trim();
    const generatedName =
      requestedName ||
      Array.from({ length: 26 }, (_, index) => String.fromCharCode(65 + index)).find(
        (name) => !existingNames.has(name),
      ) ||
      `Person ${existingMembers.length + 1}`;

    const guest = await prisma.users.create({
      data: {
        email: `guest-${crypto.randomUUID()}@billgang.local`,
        display_name: generatedName,
      },
    });
    const member = await prisma.billMembers.create({
      data: { bill_id: billId, user_id: guest.id, role: "guest" },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            display_name: true,
            avatar_url: true,
            promptpay_number: true,
          },
        },
      },
    });
    broadcast(billId, { type: "member_added", member });
    return member;
  }

  static async patchBill(userid: string, billId: string, data: BillPatchRequest) {
    await this.assertOwner(userid, billId);
    const bill = await prisma.bills.update({
      where: { id: billId },
      data: {
        ...(data.name !== undefined && { name: data.name }),
        ...(data.date !== undefined && { date: new Date(data.date) }),
        ...(data.status !== undefined && { status: data.status }),
        ...(data.receipt_total !== undefined && { receipt_total: data.receipt_total }),
        ...(data.charges_included !== undefined && { charges_included: data.charges_included }),
        ...(data.vat_pct !== undefined && { vat_pct: data.vat_pct }),
        ...(data.service_charge_pct !== undefined && {
          service_charge_pct: data.service_charge_pct,
        }),
      },
    });
    return serializeBill(bill);
  }

  static async deleteBill(userid: string, billId: string) {
    const result = await prisma.bills.deleteMany({
      where: { id: billId, created_by: userid },
    });
    return result.count > 0;
  }

  static async addItems(userid: string, billId: string, body: BillItemsRequest) {
    await this.assertMember(userid, billId);

    const items = "items" in body ? body.items : [body];
    if (items.length === 0) return [];

    const created = items.map((item) => ({
      id: crypto.randomUUID(),
      bill_id: billId,
      ...item,
    }));
    await prisma.billItems.createMany({ data: created });
    return created.map(serializeItem);
  }

  static async finalizeBill(userid: string, billId: string, data: BillFinalizeRequest) {
    await this.assertOwner(userid, billId);

    const billData = {
      ...(data.name !== undefined && { name: data.name }),
      ...(data.date !== undefined && { date: new Date(data.date) }),
      ...(data.receipt_total !== undefined && { receipt_total: data.receipt_total }),
      ...(data.charges_included !== undefined && { charges_included: data.charges_included }),
      ...(data.vat_pct !== undefined && { vat_pct: data.vat_pct }),
      ...(data.service_charge_pct !== undefined && {
        service_charge_pct: data.service_charge_pct,
      }),
    };
    const created = data.items.map((item) => ({
      id: crypto.randomUUID(),
      bill_id: billId,
      ...item,
    }));
    const [bill] = await prisma.$transaction([
      prisma.bills.update({ where: { id: billId }, data: billData }),
      prisma.billItems.createMany({ data: created }),
    ]);

    return {
      bill: serializeBill(bill),
      items: created.map(serializeItem),
    };
  }

  static async updateItem(
    userid: string,
    billId: string,
    itemId: string,
    data: BillItemUpdateRequest,
  ) {
    await this.assertMember(userid, billId);
    const item = await prisma.billItems.update({
      where: { id: itemId },
      data,
    });
    return serializeItem(item);
  }

  static async deleteItem(userid: string, billId: string, itemId: string) {
    await this.assertMember(userid, billId);
    const result = await prisma.billItems.deleteMany({
      where: { id: itemId, bill_id: billId },
    });
    return result.count > 0;
  }

  static async assignItem(userid: string, billId: string, itemId: string, assignUserId: string) {
    await this.assertMember(userid, billId);
    await this.assertMember(assignUserId, billId);
    await prisma.itemAssigns.upsert({
      where: { bill_item_id_user_id: { bill_item_id: itemId, user_id: assignUserId } },
      create: { bill_item_id: itemId, user_id: assignUserId },
      update: {},
    });
    broadcast(billId, { type: "item_assigned", item_id: itemId, user_id: assignUserId });
  }

  static async setItemAssignments(
    userid: string,
    billId: string,
    itemId: string,
    data: BillItemAssignmentsRequest,
  ) {
    await this.assertMember(userid, billId);
    const item = await prisma.billItems.findFirst({
      where: { id: itemId, bill_id: billId },
    });
    if (!item) throw new Error("NOT_FOUND");

    const assignments = data.assignments.filter((assignment) => assignment.quantity > 0);
    const userIds = assignments.map((assignment) => assignment.user_id);
    if (new Set(userIds).size !== userIds.length) throw new Error("DUPLICATE_ASSIGNMENT");
    if (assignments.reduce((sum, assignment) => sum + assignment.quantity, 0) < item.quantity) {
      throw new Error("ASSIGNMENT_QUANTITY_MISMATCH");
    }

    const members = await prisma.billMembers.findMany({
      where: { bill_id: billId, user_id: { in: userIds } },
      select: { user_id: true },
    });
    if (members.length !== userIds.length) throw new Error("FORBIDDEN");

    await prisma.$transaction([
      prisma.itemAssigns.deleteMany({ where: { bill_item_id: itemId } }),
      prisma.itemAssigns.createMany({
        data: assignments.map((assignment) => ({
          bill_item_id: itemId,
          user_id: assignment.user_id,
          assigned_quantity: assignment.quantity,
        })),
      }),
    ]);
    broadcast(billId, { type: "item_assignments_updated", item_id: itemId });
  }

  static async unassignItem(userid: string, billId: string, itemId: string, assignUserId: string) {
    await this.assertMember(userid, billId);
    await prisma.itemAssigns.deleteMany({
      where: { bill_item_id: itemId, user_id: assignUserId },
    });
    broadcast(billId, { type: "item_unassigned", item_id: itemId, user_id: assignUserId });
  }

  static async runOcr(
    userid: string,
    billId: string,
    rawText: string,
    imageUrl?: string,
    imageBase64?: string,
    imageMimeType?: string,
    imageData?: ArrayBuffer,
  ) {
    await this.assertMember(userid, billId);
    if (!rawText && !imageBase64 && !imageUrl) {
      throw new Error("RECEIPT_REQUIRED");
    }
    const saveReceiptImage = async () => {
      if (!imageData && !imageUrl) return;
      try {
        const receiptImageUrl = imageData
          ? await uploadImage(imageData, imageMimeType || "image/jpeg", "receipts")
          : imageUrl;
        if (receiptImageUrl) {
          await prisma.bills.update({
            where: { id: billId },
            data: { receipt_image_url: receiptImageUrl },
          });
        }
      } catch (error) {
        console.warn(
          "[storage] Receipt image upload/save failed; continuing without image:",
          error instanceof Error ? error.message : error,
        );
      }
    };
    void saveReceiptImage();
    const parsed = await parseReceiptText(rawText, imageBase64, imageMimeType);
    return parsed;
  }

  static async getInvite(userid: string, billId: string) {
    await this.assertMember(userid, billId);
    let bill = await prisma.bills.findUnique({ where: { id: billId } });
    if (!bill) throw new Error("NOT_FOUND");
    if (!isInviteCodeValid(bill.invite_code)) {
      bill = await prisma.bills.update({
        where: { id: billId },
        data: { invite_code: await createInviteCode() },
      });
    }
    const deepLink = `billgang://join/${bill.invite_code}`;
    return { invite_code: bill.invite_code, deep_link: deepLink };
  }

  static async joinByCode(userid: string, code: string) {
    const bill = await prisma.bills.findUnique({
      where: { invite_code: code.toUpperCase() },
    });
    if (!bill) throw new Error("NOT_FOUND");

    const existing = await prisma.billMembers.findUnique({
      where: { bill_id_user_id: { bill_id: bill.id, user_id: userid } },
    });

    if (!existing) {
      await prisma.billMembers.create({
        data: { bill_id: bill.id, user_id: userid, role: "member" },
      });
      UserStatsService.onBillJoined(userid).catch(console.error);
    }

    return this.getBill(userid, bill.id);
  }

  static async getDebts(userid: string, billId: string) {
    await this.assertMember(userid, billId);

    const bill = await prisma.bills.findUnique({
      where: { id: billId },
      include: {
        bill_items: { include: { item_assigns: true } },
        bill_members: {
          include: {
            user: {
              select: {
                id: true,
                display_name: true,
                avatar_url: true,
                promptpay_number: true,
              },
            },
          },
        },
      },
    });
    if (!bill) throw new Error("NOT_FOUND");

    // paid_by is the person who paid; if not set, defaults to created_by
    const rawPayerId = bill.paid_by;
    const memberIds = new Set(bill.bill_members.map((member) => member.user_id));
    const payerId =
      rawPayerId && memberIds.has(rawPayerId) ? rawPayerId : bill.created_by;

    const subtotal = computePersonSubtotals(
      bill.bill_members.map((m) => m.user_id),
      bill.bill_items.map((item) => ({
        unit_price: Number(decimalToNumber(item.unit_price) ?? 0),
        quantity: item.quantity,
        assignees: item.item_assigns.map((a) => ({
          user_id: a.user_id,
          assigned_quantity: a.assigned_quantity,
        })),
      })),
    );

    const vatPct = Number(decimalToNumber(bill.vat_pct) ?? 0);
    const servicePct = Number(decimalToNumber(bill.service_charge_pct) ?? 0);
    const itemSubtotal = bill.bill_items.reduce(
      (sum, item) => sum + Number(decimalToNumber(item.unit_price) ?? 0) * item.quantity,
      0,
    );
    const receiptTotal = Number(decimalToNumber(bill.receipt_total) ?? 0) || undefined;
    const { owed, balances } = computeOwedAndBalances(subtotal, vatPct, servicePct, payerId, {
      itemSubtotal,
      receiptTotal,
      chargesIncluded: bill.charges_included,
    });

    const transfers: Transfer[] = minCashFlow(balances);

    const memberById = new Map(bill.bill_members.map((m) => [m.user_id, m.user]));

    const perPerson = bill.bill_members.map((m) => ({
      user_id: m.user_id,
      user: m.user,
      subtotal: round2(subtotal[m.user_id] ?? 0),
      owed: round2(owed[m.user_id] ?? 0),
      balance: round2(balances[m.user_id] ?? 0),
    }));

    return {
      per_person: perPerson,
      transfers: transfers.map((t) => ({
        from_user_id: t.from,
        to_user_id: t.to,
        from_user: memberById.get(t.from) ?? null,
        to_user: memberById.get(t.to) ?? null,
        amount: t.amount,
      })),
      bill: serializeBill({ ...bill, bill_items: undefined, bill_members: undefined }),
    };
  }

  static async setPayer(userid: string, billId: string, payerId: string) {
    // Verify requesting user is a member
    await this.assertMember(userid, billId);
    await this.assertMember(payerId, billId);

    const bill = await prisma.bills.update({
      where: { id: billId },
      data: { paid_by: payerId },
    });
    broadcast(billId, { type: "payer_set", paid_by: payerId });
    return serializeBill(bill);
  }

  static async markPaid(userid: string, billId: string) {
    const bill = await this.assertOwner(userid, billId);
    const details = await this.getBill(userid, billId);
    if (
      details.items.length === 0 ||
      details.items.some((item) => {
        const assignedQuantity = item.item_assigns.reduce(
          (sum: number, assign: { assigned_quantity: number | null }) =>
            sum + (assign.assigned_quantity ?? item.quantity / item.item_assigns.length),
          0,
        );
        return assignedQuantity < item.quantity;
      })
    ) {
      throw new Error("ITEMS_NOT_ASSIGNED");
    }
    const debts = await this.getDebts(userid, billId);
    if (debts.transfers.length > 0) throw new Error("PAYMENT_NOT_SETTLED");

    const updated = await prisma.bills.update({
      where: { id: bill.id },
      data: { status: "settled" },
    });
    broadcast(billId, { type: "bill_paid", bill: serializeBill(updated) });
    return serializeBill(updated);
  }
}

