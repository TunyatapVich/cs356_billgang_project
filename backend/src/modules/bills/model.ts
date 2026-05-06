import Elysia, { t, type Static } from "elysia";
import { BillsPlain } from "../../../generated/prismabox/Bills";

export const BillCreatePayload = t.Object({
  name: t.String(),
  date: t.Date(),
  vat_pct: t.Number({ minimum: 0 }),
});

export const BillDeleteParams = t.Object({
  id: t.String(),
});

export type BillCreateRequest = Static<typeof BillCreatePayload>;

const BillCreateResponse = t.Object({
  bill: BillsPlain,
});

const MessageResponse = t.Object({
  message: t.String(),
});

export const BillModel = new Elysia({ name: "Model.Bill" }).model({
  "bills.create.request": BillCreatePayload,
  "bills.create.response": BillCreateResponse,
  "bills.create.error": MessageResponse,
  "bills.delete.response": MessageResponse,
  "bills.delete.error": MessageResponse,
});
