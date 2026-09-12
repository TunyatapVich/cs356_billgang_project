import { prisma } from "../../db";
import { decimalToNumber } from "../utils/decimal";
import { generatePromptPayPayload } from "../utils/promptpay";
import { UserStatsService } from "../users/service";
import { BillService } from "../bills/service";
import type { PaymentCreateRequest, PaymentLocalConfirmRequest } from "./model";

const serializePayment = (p: any) => ({
  ...p,
  amount: decimalToNumber(p.amount),
});

export const PAYMENT_STATUS = {
  PENDING: "pending",
  CONFIRMED: "confirmed",
} as const;

const assertMember = async (userid: string, billId: string) => {
  const member = await prisma.billMembers.findUnique({
    where: { bill_id_user_id: { bill_id: billId, user_id: userid } },
  });
  if (!member) throw new Error("FORBIDDEN");
};

export class PaymentService {
  static async listByBill(userid: string, billId: string) {
    await assertMember(userid, billId);
    const payments = await prisma.payments.findMany({
      where: { bill_id: billId },
      orderBy: { created_at: "desc" },
      include: {
        from_user: {
          select: { id: true, display_name: true, avatar_url: true },
        },
        to_user: {
          select: {
            id: true,
            display_name: true,
            avatar_url: true,
            promptpay_number: true,
          },
        },
      },
    });
    return payments.map(serializePayment);
  }

  static async getById(userid: string, paymentId: string) {
    const payment = await prisma.payments.findUnique({
      where: { id: paymentId },
      include: {
        from_user: {
          select: { id: true, display_name: true, avatar_url: true },
        },
        to_user: {
          select: {
            id: true,
            display_name: true,
            avatar_url: true,
            promptpay_number: true,
          },
        },
      },
    });
    if (!payment) throw new Error("NOT_FOUND");
    await assertMember(userid, payment.bill_id);
    return {
      payment: serializePayment(payment),
      qr_data: payment.status === PAYMENT_STATUS.PENDING && payment.to_user.promptpay_number
        ? generatePromptPayPayload(payment.to_user.promptpay_number, Number(decimalToNumber(payment.amount) ?? 0))
        : null,
    };
  }

  static async create(userid: string, data: PaymentCreateRequest) {
    if (data.from_user_id !== userid) throw new Error("FORBIDDEN");
    await assertMember(userid, data.bill_id);
    await assertMember(data.to_user_id, data.bill_id);

    const debts = await BillService.getDebts(userid, data.bill_id);
    const transfer = debts.transfers.find(
      (item) => item.from_user_id === data.from_user_id && item.to_user_id === data.to_user_id,
    );
    if (!transfer) throw new Error("PAYMENT_NOT_REQUIRED");
    const amount = transfer.amount;

    const toUser = await prisma.users.findUnique({
      where: { id: data.to_user_id },
      select: {
        id: true,
        display_name: true,
        avatar_url: true,
        promptpay_number: true,
      },
    });
    if (!toUser) throw new Error("RECIPIENT_NOT_FOUND");

    const existing = await prisma.payments.findFirst({
      where: {
        bill_id: data.bill_id,
        from_user_id: data.from_user_id,
        to_user_id: data.to_user_id,
      },
      orderBy: { created_at: "desc" },
    });

    const payment = existing
      ? existing.status === PAYMENT_STATUS.PENDING
        ? await prisma.payments.update({
            where: { id: existing.id },
            data: { amount },
          })
        : existing
      : await prisma.payments.create({
          data: {
            bill_id: data.bill_id,
            from_user_id: data.from_user_id,
            to_user_id: data.to_user_id,
            amount,
            status: PAYMENT_STATUS.PENDING,
          },
        });

    const qrData = payment.status === PAYMENT_STATUS.PENDING && toUser.promptpay_number
      ? generatePromptPayPayload(toUser.promptpay_number, amount)
      : null;

    return {
      payment: serializePayment(payment),
      payment_id: payment.id,
      qr_data: qrData,
      to_user: toUser,
      amount,
    };
  }

  static async confirm(userid: string, paymentId: string) {
    const existing = await prisma.payments.findUnique({
      where: { id: paymentId },
    });
    if (!existing) throw new Error("NOT_FOUND");
    await assertMember(userid, existing.bill_id);
    if (existing.from_user_id !== userid) {
      throw new Error("FORBIDDEN");
    }

    if (existing.status === PAYMENT_STATUS.CONFIRMED) {
      return {
        payment: serializePayment(existing),
        bill_settled: false,
      };
    }
    if (existing.status !== PAYMENT_STATUS.PENDING) throw new Error("PAYMENT_NOT_PENDING");

    const updated = await prisma.payments.updateMany({
      where: {
        id: paymentId,
        from_user_id: userid,
        status: PAYMENT_STATUS.PENDING,
      },
      data: { status: PAYMENT_STATUS.CONFIRMED },
    });
    if (updated.count === 0) {
      const current = await prisma.payments.findUnique({ where: { id: paymentId } });
      if (current?.status === PAYMENT_STATUS.CONFIRMED) {
        return { payment: serializePayment(current), bill_settled: false };
      }
      throw new Error("PAYMENT_NOT_PENDING");
    }

    const payment = await prisma.payments.findUnique({ where: { id: paymentId } });
    if (!payment) throw new Error("NOT_FOUND");

    const billSettled = await this._isBillSettled(userid, payment.bill_id);
    if (billSettled) {
      await prisma.bills.update({
        where: { id: payment.bill_id },
        data: { status: "settled" },
      });
    }

    await Promise.all([
      UserStatsService.upsertStats(payment.from_user_id),
      UserStatsService.upsertStats(payment.to_user_id),
    ]);
    await UserStatsService.onPaymentConfirmed(
      payment.from_user_id,
      payment.to_user_id,
      Number(decimalToNumber(payment.amount) ?? 0),
    );

    return { payment: serializePayment(payment), bill_settled: billSettled };
  }

  static async confirmLocal(userid: string, data: PaymentLocalConfirmRequest) {
    const bill = await prisma.bills.findUnique({ where: { id: data.bill_id } });
    if (!bill) throw new Error("NOT_FOUND");
    if (bill.created_by !== userid) throw new Error("FORBIDDEN");

    const fromMember = await prisma.billMembers.findUnique({
      where: { bill_id_user_id: { bill_id: data.bill_id, user_id: data.from_user_id } },
    });
    const toMember = await prisma.billMembers.findUnique({
      where: { bill_id_user_id: { bill_id: data.bill_id, user_id: data.to_user_id } },
    });
    if (!fromMember || !toMember) throw new Error("FORBIDDEN");
    if (fromMember.role !== "guest" && toMember.role !== "guest") {
      throw new Error("LOCAL_PAYMENT_ONLY");
    }

    const debts = await BillService.getDebts(userid, data.bill_id);
    const transfer = debts.transfers.find(
      (item) =>
        item.from_user_id === data.from_user_id && item.to_user_id === data.to_user_id,
    );
    if (!transfer) throw new Error("PAYMENT_NOT_REQUIRED");

    const existing = await prisma.payments.findFirst({
      where: {
        bill_id: data.bill_id,
        from_user_id: data.from_user_id,
        to_user_id: data.to_user_id,
      },
      orderBy: { created_at: "desc" },
    });
    if (existing?.status === PAYMENT_STATUS.CONFIRMED) {
      return { payment: serializePayment(existing), bill_settled: false };
    }

    const payment = existing
      ? await prisma.payments.update({
          where: { id: existing.id },
          data: { amount: transfer.amount, status: PAYMENT_STATUS.CONFIRMED },
        })
      : await prisma.payments.create({
          data: {
            bill_id: data.bill_id,
            from_user_id: data.from_user_id,
            to_user_id: data.to_user_id,
            amount: transfer.amount,
            status: PAYMENT_STATUS.CONFIRMED,
          },
        });
    const billSettled = await this._isBillSettled(userid, data.bill_id);
    if (billSettled) {
      await prisma.bills.update({
        where: { id: data.bill_id },
        data: { status: "settled" },
      });
    }
    await Promise.all([
      UserStatsService.upsertStats(payment.from_user_id),
      UserStatsService.upsertStats(payment.to_user_id),
    ]);
    await UserStatsService.onPaymentConfirmed(
      payment.from_user_id,
      payment.to_user_id,
      Number(decimalToNumber(payment.amount) ?? 0),
    );

    return { payment: serializePayment(payment), bill_settled: billSettled };
  }

  private static async _isBillSettled(userid: string, billId: string) {
    const debts = await BillService.getDebts(userid, billId);
    const transfers = debts.transfers ?? [];
    if (transfers.length === 0) return true;

    const confirmed = await prisma.payments.findMany({
      where: { bill_id: billId, status: "confirmed" },
    });

    return transfers.every((transfer) => {
      const paid = confirmed
        .filter(
          (payment) =>
            payment.from_user_id === transfer.from_user_id &&
            payment.to_user_id === transfer.to_user_id,
        )
        .reduce(
          (sum, payment) => sum + Number(decimalToNumber(payment.amount) ?? 0),
          0,
        );
      return paid + 0.01 >= transfer.amount;
    });
  }
}
