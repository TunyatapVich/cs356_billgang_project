import { Elysia, t } from "elysia";
import {
  BillCreatePayload,
  BillIdParams,
  BillItemIdParams,
  BillItemUpdatePayload,
  BillItemsPayload,
  BillJoinParams,
  BillModel,
  BillOcrPayload,
  BillPatchPayload,
  BillPayerPayload,
} from "./model";
import { BillService } from "./service";
import { authPlugin } from "../utils/auth";
import { broadcast } from "../utils/broker";

const handleError = (err: any, set: any) => {
  if (err?.message === "FORBIDDEN") {
    set.status = 403;
    return { message: "Forbidden" };
  }
  if (err?.message === "NOT_FOUND") {
    set.status = 404;
    return { message: "Not found" };
  }
  set.status = 400;
  return { message: err?.message ?? "Bad request" };
};

export const BillModule = new Elysia({ prefix: "/bills" })
  .use(BillModel)
  .use(authPlugin)

  .get("/", async ({ userid, set }) => {
    if (!userid) {
      set.status = 401;
      return { message: "Unauthorized" };
    }
    const bills = await BillService.listBills(userid);
    return { bills };
  })

  .post(
    "/",
    async ({ body, set, userid }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        const bill = await BillService.createBill(userid, body);
        set.status = 201;
        return { bill };
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { body: BillCreatePayload },
  )

  .get(
    "/:id",
    async ({ params, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        return await BillService.getBill(userid, params.id);
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { params: BillIdParams },
  )

  .patch(
    "/:id",
    async ({ params, body, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        const bill = await BillService.patchBill(userid, params.id, body);
        broadcast(params.id, { type: "bill_updated", bill });
        return { bill };
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { params: BillIdParams, body: BillPatchPayload },
  )

  .delete(
    "/:id",
    async ({ params, set, userid }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      const deleted = await BillService.deleteBill(userid, params.id);
      if (!deleted) {
        set.status = 404;
        return { message: "Bill not found" };
      }
      return { message: "Bill deleted" };
    },
    { params: BillIdParams },
  )

  .post(
    "/:id/items",
    async ({ params, body, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        const items = await BillService.addItems(userid, params.id, body);
        for (const item of items) broadcast(params.id, { type: "item_added", item });
        return { items };
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { params: BillIdParams, body: BillItemsPayload },
  )

  .put(
    "/:id/items/:itemId",
    async ({ params, body, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        const item = await BillService.updateItem(userid, params.id, params.itemId, body);
        broadcast(params.id, { type: "item_updated", item });
        return { item };
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { params: BillItemIdParams, body: BillItemUpdatePayload },
  )

  .delete(
    "/:id/items/:itemId",
    async ({ params, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        const ok = await BillService.deleteItem(userid, params.id, params.itemId);
        if (!ok) {
          set.status = 404;
          return { message: "Item not found" };
        }
        broadcast(params.id, { type: "item_removed", item_id: params.itemId });
        return { message: "Item deleted" };
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { params: BillItemIdParams },
  )

  .post(
    "/:id/items/:itemId/assign",
    async ({ params, body, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        await BillService.assignItem(userid, params.id, params.itemId, body.user_id);
        return { message: "Assigned" };
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { params: BillItemIdParams, body: t.Object({ user_id: t.String() }) },
  )

  .delete(
    "/:id/items/:itemId/assign/:assignUserId",
    async ({ params, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        await BillService.unassignItem(userid, params.id, params.itemId, params.assignUserId);
        return { message: "Unassigned" };
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { params: t.Object({ id: t.String(), itemId: t.String(), assignUserId: t.String() }) },
  )

  .post(
    "/:id/ocr",
    async ({ params, body, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        const buffer = await body.image.arrayBuffer();
        return await BillService.runOcr(userid, params.id, buffer, body.image.type || "image/jpeg");
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { params: BillIdParams, body: BillOcrPayload },
  )

  .post(
    "/:id/invite",
    async ({ params, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        return await BillService.getInvite(userid, params.id);
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { params: BillIdParams },
  )

  .post(
    "/join/:code",
    async ({ params, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        const result = await BillService.joinByCode(userid, params.code);
        const joinedMember = result.members.find((m) => m.user_id === userid);
        if (joinedMember) {
          broadcast(result.bill.id, { type: "member_joined", member: joinedMember });
        }
        return result;
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { params: BillJoinParams },
  )

  .get(
    "/:id/debts",
    async ({ params, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        return await BillService.getDebts(userid, params.id);
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { params: BillIdParams },
  )

  .patch(
    "/:id/payer",
    async ({ params, body, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        const bill = await BillService.setPayer(userid, params.id, body.paid_by);
        return { bill };
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { params: BillIdParams, body: BillPayerPayload },
  );
