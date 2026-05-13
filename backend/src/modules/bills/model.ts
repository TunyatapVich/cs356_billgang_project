import Elysia, { t, type Static } from "elysia";

export const BillCreatePayload = t.Object({
  name: t.String(),
  date: t.String(),
  vat_pct: t.Optional(t.Number({ minimum: 0 })),
  service_charge_pct: t.Optional(t.Number({ minimum: 0 })),
});
export type BillCreateRequest = Static<typeof BillCreatePayload>;

export const BillIdParams = t.Object({ id: t.String() });
export const BillItemIdParams = t.Object({ id: t.String(), itemId: t.String() });
export const BillJoinParams = t.Object({ code: t.String() });

export const BillPatchPayload = t.Object({
  name: t.Optional(t.String()),
  date: t.Optional(t.String()),
  status: t.Optional(t.String()),
  vat_pct: t.Optional(t.Number({ minimum: 0 })),
  service_charge_pct: t.Optional(t.Number({ minimum: 0 })),
});
export type BillPatchRequest = Static<typeof BillPatchPayload>;

export const BillPayerPayload = t.Object({ paid_by: t.String() });
export type BillPayerRequest = Static<typeof BillPayerPayload>;

const ItemInput = t.Object({
  name: t.String(),
  quantity: t.Integer({ minimum: 1 }),
  unit_price: t.Number({ minimum: 0 }),
});

export const BillItemsPayload = t.Union([
  ItemInput,
  t.Object({ items: t.Array(ItemInput) }),
]);
export type BillItemsRequest = Static<typeof BillItemsPayload>;

export const BillItemUpdatePayload = t.Object({
  name: t.Optional(t.String()),
  quantity: t.Optional(t.Integer({ minimum: 1 })),
  unit_price: t.Optional(t.Number({ minimum: 0 })),
});
export type BillItemUpdateRequest = Static<typeof BillItemUpdatePayload>;

export const BillOcrPayload = t.Object({
  image: t.File(),
});
export type BillOcrRequest = Static<typeof BillOcrPayload>;

const MessageResponse = t.Object({ message: t.String() });

export const BillModel = new Elysia({ name: "Model.Bill" }).model({
  "bills.create.request": BillCreatePayload,
  "bills.create.error": MessageResponse,
  "bills.delete.response": MessageResponse,
  "bills.delete.error": MessageResponse,
  "bills.error": MessageResponse,
});
