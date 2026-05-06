import { prisma } from "../../db";
import type { BillCreateRequest } from "./model";

type DecimalLike =
  | number
  | string
  | null
  | {
      toNumber?: () => number;
      toString: () => string;
    };

const decimalToNumber = (value: DecimalLike) => {
  if (value === null) return null;
  if (typeof value === "number") return value;
  if (typeof value === "string") return Number(value);
  if (value.toNumber) return value.toNumber();
  return Number(value.toString());
};

export class BillService {
  static async listBills(userid?: string | null) {
    const bills = await prisma.bills.findMany({
      where: userid
        ? {
            bill_members: {
              some: {
                user_id: userid,
              },
            },
          }
        : undefined,
      include: {
        _count: {
          select: {
            bill_members: true,
          },
        },
      },
      orderBy: {
        created_at: "desc",
      },
    });

    return bills.map((bill) => ({
      ...bill,
      service_charge_pct: decimalToNumber(bill.service_charge_pct),
      vat_pct: decimalToNumber(bill.vat_pct),
      member_count: bill._count.bill_members,
    }));
  }

  static async createBill(userid: string, data: BillCreateRequest) {
    try {
      const bill = await prisma.bills.create({
        data: {
          created_by: userid,
          name: data.name,
          date: new Date(data.date),
          vat_pct: data.vat_pct,
          status: "Active",
          service_charge_pct: 0,
          invite_code: Math.random().toString(36).substring(2, 8).toUpperCase(),
          bill_members: {
            create: {
              user_id: userid,
              role: "Owner",
            },
          },
        },
      });
      return {
        ...bill,
        service_charge_pct: decimalToNumber(bill.service_charge_pct),
        vat_pct: decimalToNumber(bill.vat_pct),
      };
    } catch (error: any) {
      throw error;
    }
  }

  static async deleteBill(userid: string, billId: string) {
    const result = await prisma.bills.deleteMany({
      where: {
        id: billId,
        created_by: userid,
      },
    });

    return result.count > 0;
  }
}
