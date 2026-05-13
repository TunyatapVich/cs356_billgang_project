import { prisma } from "../../db";
import { decimalToNumber } from "../utils/decimal";
import { generatePromptPayPayload } from "../utils/promptpay";
import { UserStatsService } from "../users/service";
import { BillService } from "../bills/service";

const serializePayment = (p: any) => ({
  ...p,
  amount: decimalToNumber(p.amount),
});

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

  static async create(userid: string, data: PaymentCreateRequest) {
    if (data.from_user_id !== userid) throw new Error("FORBIDDEN");
    await assertMember(userid, data.bill_id);

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
        status: "pending",
      },
      orderBy: { created_at: "desc" },
    });

    const payment = existing
      ? await prisma.payments.update({
          where: { id: existing.id },
          data: { amount: data.amount },
        })
      : await prisma.payments.create({
          data: {
            bill_id: data.bill_id,
            from_user_id: data.from_user_id,
            to_user_id: data.to_user_id,
            amount: data.amount,
            status: "pending",
          },
        });

    const qrData = toUser.promptpay_number
      ? generatePromptPayPayload(toUser.promptpay_number, data.amount)
      : null;

    return {
      payment: serializePayment(payment),
      payment_id: payment.id,
      qr_data: qrData,
      to_user: toUser,
    };
  }

  static async confirm(userid: string, paymentId: string, slipUrl?: string) {
    if (!slipUrl) throw new Error("SLIP_REQUIRED");

    const existing = await prisma.payments.findUnique({
      where: { id: paymentId },
    });
    if (!existing) throw new Error("NOT_FOUND");
    if (existing.from_user_id !== userid && existing.to_user_id !== userid) {
      throw new Error("FORBIDDEN");
    }

    const payment = await prisma.payments.update({
      where: { id: paymentId },
      data: {
        status: "confirmed",
        ...(slipUrl !== undefined && { slip_url: slipUrl }),
      },
    });

    const billSettled = await this._isBillSettled(userid, payment.bill_id);
    if (billSettled) {
      await prisma.bills.update({
        where: { id: payment.bill_id },
        data: { status: "settled" },
      });
    }

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
