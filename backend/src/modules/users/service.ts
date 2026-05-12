import { prisma } from "../../db";
import { decimalToNumber } from "../utils/decimal";
import { minCashFlow, type Transfer } from "../utils/mincashflow";

const serializeStats = (s: any) => ({
  total_paid: decimalToNumber(s.total_paid),
  total_received: decimalToNumber(s.total_received),
  bills_count: s.bills_count,
  bills_owned: s.bills_owned,
});

export class UserStatsService {
  static async getStats(userId: string) {
    const stats = await prisma.userStats.findUnique({
      where: { user_id: userId },
    });
    if (!stats) {
      return {
        total_paid: 0,
        total_received: 0,
        bills_count: 0,
        bills_owned: 0,
      };
    }
    return serializeStats(stats);
  }

  static async getPartners(userId: string) {
    const bills = await prisma.bills.findMany({
      where: { bill_members: { some: { user_id: userId } } },
      include: {
        bill_items: { include: { item_assigns: true } },
        bill_members: {
          include: {
            user: { select: { id: true, display_name: true, avatar_url: true } },
          },
        },
      },
    });

    const partnerTotals: Record<string, number> = {};

    for (const bill of bills) {
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
      for (const [uid, amt] of Object.entries(subtotal)) {
        owed[uid] = amt * multiplier;
      }

      const balances: Record<string, number> = {};
      for (const uid of Object.keys(owed)) balances[uid] = -owed[uid];
      balances[bill.created_by] = (balances[bill.created_by] ?? 0) + Object.values(owed).reduce((a, b) => a + b, 0);

      const transfers: Transfer[] = minCashFlow(balances);

      for (const t of transfers) {
        if (t.from === userId) {
          partnerTotals[t.to] = (partnerTotals[t.to] ?? 0) + t.amount;
        }
        if (t.to === userId) {
          partnerTotals[t.from] = (partnerTotals[t.from] ?? 0) - t.amount;
        }
      }
    }

    const partnerIds = Object.keys(partnerTotals).filter((id) => id !== userId);
    if (partnerIds.length === 0) return { partners: [] };

    const users = await prisma.users.findMany({
      where: { id: { in: partnerIds } },
      select: { id: true, display_name: true, avatar_url: true },
    });
    const userMap = new Map(users.map((u) => [u.id, u]));

    return {
      partners: partnerIds.map((id) => ({
        user_id: id,
        display_name: userMap.get(id)?.display_name ?? null,
        avatar_url: userMap.get(id)?.avatar_url ?? null,
        total_paid_to: Math.round((partnerTotals[id] ?? 0) * 100) / 100,
      })),
    };
  }

  static async upsertStats(userId: string) {
    return prisma.userStats.upsert({
      where: { user_id: userId },
      update: { updated_at: new Date() },
      create: {
        user_id: userId,
        total_paid: 0,
        total_received: 0,
        bills_count: 0,
        bills_owned: 0,
      },
    });
  }

  static async onUserRegistered(userId: string) {
    return this.upsertStats(userId);
  }

  static async onBillCreated(userId: string) {
    await this.upsertStats(userId);
    return prisma.userStats.update({
      where: { user_id: userId },
      data: { bills_owned: { increment: 1 } },
    });
  }

  static async onBillJoined(userId: string) {
    await this.upsertStats(userId);
    return prisma.userStats.update({
      where: { user_id: userId },
      data: { bills_count: { increment: 1 } },
    });
  }

  static async onPaymentConfirmed(fromUserId: string, toUserId: string, amount: number) {
    const updates = [];
    updates.push(
      prisma.userStats.update({
        where: { user_id: fromUserId },
        data: { total_paid: { increment: amount } },
      }),
    );
    updates.push(
      prisma.userStats.update({
        where: { user_id: toUserId },
        data: { total_received: { increment: amount } },
      }),
    );
    return prisma.$transaction(updates);
  }
}
