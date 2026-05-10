import { prisma } from "../../db";
import { decimalToNumber } from "../utils/decimal";

const serializeItem = (item: any) => ({
  ...item,
  unit_price: decimalToNumber(item.unit_price),
});

export class WsBillService {
  static async getSnapshot(billId: string) {
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
    if (!bill) return null;

    return {
      bill_id: bill.id,
      items: bill.bill_items.map(serializeItem),
      assigns: bill.bill_items.flatMap((i) => i.item_assigns),
      members: bill.bill_members.map((m) => ({
        bill_id: m.bill_id,
        user_id: m.user_id,
        role: m.role,
        joined_at: m.joined_at,
        user: m.user,
      })),
    };
  }

  static async assertMember(userid: string, billId: string) {
    const member = await prisma.billMembers.findUnique({
      where: { bill_id_user_id: { bill_id: billId, user_id: userid } },
    });
    return !!member;
  }

  static async addItem(
    billId: string,
    payload: { name: string; quantity: number; unit_price: number },
  ) {
    const item = await prisma.billItems.create({
      data: {
        bill_id: billId,
        name: payload.name,
        quantity: payload.quantity,
        unit_price: payload.unit_price,
      },
    });
    return serializeItem(item);
  }

  static async removeItem(billId: string, itemId: string) {
    const result = await prisma.billItems.deleteMany({
      where: { id: itemId, bill_id: billId },
    });
    return result.count > 0;
  }

  static async assignItem(itemId: string, userId: string) {
    const assign = await prisma.itemAssigns.upsert({
      where: { bill_item_id_user_id: { bill_item_id: itemId, user_id: userId } },
      update: {},
      create: { bill_item_id: itemId, user_id: userId },
    });
    return assign;
  }

  static async unassignItem(itemId: string, userId: string) {
    const result = await prisma.itemAssigns.deleteMany({
      where: { bill_item_id: itemId, user_id: userId },
    });
    return result.count > 0;
  }
}
