import { Elysia, t } from "elysia";
import {
  BillCreatePayload,
  BillFinalizePayload,
  BillIdParams,
  BillItemAssignmentsPayload,
  BillItemIdParams,
  BillItemUpdatePayload,
  BillItemsPayload,
  BillJoinParams,
  BillMemberCreatePayload,
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
  if (err?.message === "ITEMS_NOT_ASSIGNED") {
    set.status = 400;
    return { message: "Assign every item before marking the bill as paid." };
  }
  if (err?.message === "PAYMENT_NOT_SETTLED") {
    set.status = 400;
    return { message: "Complete all transfers before marking the bill as paid." };
  }
  if (err?.message === "ASSIGNMENT_QUANTITY_MISMATCH") {
    set.status = 400;
    return { message: "Assigned quantities must cover at least the item quantity." };
  }
  if (err?.message === "DUPLICATE_ASSIGNMENT") {
    set.status = 400;
    return { message: "Each person can only be assigned once per item." };
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

  .post(
    "/:id/members",
    async ({ params, body, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        const member = await BillService.addMember(userid, params.id, body);
        return { member };
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { params: BillIdParams, body: BillMemberCreatePayload },
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

  .post(
    "/:id/mark-paid",
    async ({ params, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        const bill = await BillService.markPaid(userid, params.id);
        return { bill };
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { params: BillIdParams },
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

  .post(
    "/:id/finalize",
    async ({ params, body, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        const result = await BillService.finalizeBill(userid, params.id, body);
        broadcast(params.id, { type: "bill_updated", bill: result.bill });
        for (const item of result.items) {
          broadcast(params.id, { type: "item_added", item });
        }
        return result;
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { params: BillIdParams, body: BillFinalizePayload },
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

  .put(
    "/:id/items/:itemId/assignments",
    async ({ params, body, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        await BillService.setItemAssignments(userid, params.id, params.itemId, body);
        return { message: "Assignments updated" };
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { params: BillItemIdParams, body: BillItemAssignmentsPayload },
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
        const imageData = body.image ? await body.image.arrayBuffer() : undefined;
        const imageBase64 = imageData ? Buffer.from(imageData).toString("base64") : undefined;
        return await BillService.runOcr(
          userid,
          params.id,
          body.raw_text ?? "",
          body.image_url,
          imageBase64,
          body.image?.type,
          imageData,
        );
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
