import Elysia, { t, type Static } from "elysia";

export const PaymentCreatePayload = t.Object({
  bill_id: t.String(),
  from_user_id: t.String(),
  to_user_id: t.String(),
  amount: t.Number({ minimum: 0 }),
});
export type PaymentCreateRequest = Static<typeof PaymentCreatePayload>;

export const PaymentLocalConfirmPayload = t.Object({
  bill_id: t.String(),
  from_user_id: t.String(),
  to_user_id: t.String(),
});
export type PaymentLocalConfirmRequest = Static<typeof PaymentLocalConfirmPayload>;

export const PaymentConfirmPayload = t.Object({
});
export type PaymentConfirmRequest = Static<typeof PaymentConfirmPayload>;

export const PaymentIdParams = t.Object({ id: t.String() });

export const PaymentListQuery = t.Object({
  bill_id: t.Optional(t.String()),
});

const MessageResponse = t.Object({ message: t.String() });

export const PaymentModel = new Elysia({ name: "Model.Payment" }).model({
  "payments.error": MessageResponse,
});
