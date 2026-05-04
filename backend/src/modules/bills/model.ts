import Elysia, { t, type Static } from "elysia";
import { UsersPlain } from "../../../generated/prismabox/Users";
import { __nullable__ } from "../../../generated/prismabox/__nullable__";
import { BillsPlain } from "../../../generated/prismabox/Bills";

export const BillCreatePayload = t.Object({
    name: t.String(),
    date: t.Date(),
    vat_pct: t.Number({ minimum: 0 }),
});

export type BillCreateRequest = Static<typeof BillCreatePayload>;

const ErrorResponse = t.Object({
  message: t.String(),
});


export const BillModel = new Elysia({ name: "Model.Bill" }).model({
    "bills.create.request": BillCreatePayload,
    "bills.create.response": BillsPlain, 
    "bills.create.error": ErrorResponse,
});
