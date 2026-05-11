import { prisma } from "../../db";
import { decimalToNumber } from "../utils/decimal";
import { minCashFlow, type Transfer } from "../utils/mincashflow";
import { parseReceiptText, type ParsedItem } from "../utils/ocr";
import type {
  BillCreateRequest,
  BillItemsRequest,
  BillItemUpdateRequest,
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

    return {
      bill: serializeBill({ ...bill, bill_items: undefined, bill_members: undefined }),
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
    return serializeBill(bill);
  }

  static async patchBill(userid: string, billId: string, data: BillPatchRequest) {
    await this.assertOwner(userid, billId);
    const bill = await prisma.bills.update({
      where: { id: billId },
      data: {
        ...(data.name !== undefined && { name: data.name }),
        ...(data.date !== undefined && { date: new Date(data.date) }),
        ...(data.status !== undefined && { status: data.status }),
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

    if (items.length === 1) {
      const created = await prisma.billItems.create({
        data: { bill_id: billId, ...items[0] },
      });
      return [serializeItem(created)];
    }

    await prisma.billItems.createMany({
      data: items.map((it) => ({ bill_id: billId, ...it })),
    });
    const recent = await prisma.billItems.findMany({
      where: { bill_id: billId },
      orderBy: { created_at: "desc" },
      take: items.length,
    });
    return recent.reverse().map(serializeItem);
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

  static async runOcr(userid: string, billId: string, rawText: string, imageUrl?: string) {
    await this.assertMember(userid, billId);
    if (imageUrl) {
      await prisma.bills.update({
        where: { id: billId },
        data: { receipt_image_url: imageUrl },
      });
    }
    const items = await parseReceiptText(rawText);
    return { items } as { items: ParsedItem[] };
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

    await prisma.billMembers.upsert({
      where: { bill_id_user_id: { bill_id: bill.id, user_id: userid } },
      update: {},
      create: { bill_id: bill.id, user_id: userid, role: "member" },
    });

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

    const subtotal: Record<string, number> = {};
    for (const member of bill.bill_members) subtotal[member.user_id] = 0;

    for (const item of bill.bill_items) {
      const price = Number(decimalToNumber(item.unit_price) ?? 0);
      const lineTotal = price * item.quantity;
      const assignees = item.item_assigns.map((a) => a.user_id);
      if (assignees.length === 0) continue;
      const share = lineTotal / assignees.length;
      for (const u of assignees) subtotal[u] = (subtotal[u] ?? 0) + share;
    }

    const vat = Number(decimalToNumber(bill.vat_pct) ?? 0) / 100;
    const service = Number(decimalToNumber(bill.service_charge_pct) ?? 0) / 100;
    const multiplier = (1 + service) * (1 + vat);

    const owed: Record<string, number> = {};
    let totalOwed = 0;
    for (const [userId, amt] of Object.entries(subtotal)) {
      const final = amt * multiplier;
      owed[userId] = final;
      totalOwed += final;
    }

    const balances: Record<string, number> = {};
    for (const userId of Object.keys(owed)) {
      balances[userId] = -owed[userId];
    }
    balances[bill.created_by] = (balances[bill.created_by] ?? 0) + totalOwed;

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
}

const round2 = (n: number) => Math.round(n * 100) / 100;
