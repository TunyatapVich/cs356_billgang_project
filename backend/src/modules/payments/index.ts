import { Elysia } from "elysia";
import {
  PaymentConfirmPayload,
  PaymentCreatePayload,
  PaymentIdParams,
  PaymentListQuery,
  PaymentLocalConfirmPayload,
  PaymentModel,
} from "./model";
import { PaymentService } from "./service";
import { authPlugin } from "../utils/auth";
import { broadcast } from "../utils/broker";

const handleError = (err: any, set: any) => {
  if (err?.message === "FORBIDDEN") {
    set.status = 403;
    return { message: "Forbidden" };
  }
  if (err?.message === "NOT_FOUND" || err?.message === "RECIPIENT_NOT_FOUND") {
    set.status = 404;
    return { message: "Not found" };
  }
  if (err?.message === "PAYMENT_NOT_REQUIRED") {
    set.status = 400;
    return { message: "This transfer is no longer payable." };
  }
  if (err?.message === "PAYMENT_NOT_PENDING") {
    set.status = 409;
    return { message: "This payment has already been confirmed." };
  }
  if (err?.message === "LOCAL_PAYMENT_ONLY") {
    set.status = 400;
    return { message: "Only local people can be confirmed by the bill creator." };
  }
  set.status = 400;
  return { message: err?.message ?? "Bad request" };
};

export const PaymentModule = new Elysia({ prefix: "/payments" })
  .use(PaymentModel)
  .use(authPlugin)

  .get(
    "/",
    async ({ query, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      if (!query.bill_id) {
        set.status = 400;
        return { message: "bill_id query param required" };
      }
      try {
        const payments = await PaymentService.listByBill(userid, query.bill_id);
        return { payments };
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { query: PaymentListQuery },
  )

  .get(
    "/:id",
    async ({ params, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        return await PaymentService.getById(userid, params.id);
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { params: PaymentIdParams },
  )

  .post(
    "/",
    async ({ body, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        const result = await PaymentService.create(userid, body);
        broadcast(body.bill_id, { type: "payment_created", payment: result.payment });
        return result;
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { body: PaymentCreatePayload },
  )

  .post(
    "/local-confirm",
    async ({ body, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        const result = await PaymentService.confirmLocal(userid, body);
        broadcast(body.bill_id, {
          type: "payment_confirmed",
          payment: result.payment,
          bill_settled: result.bill_settled,
        });
        return result;
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { body: PaymentLocalConfirmPayload },
  )

  .put(
    "/:id/confirm",
    async ({ params, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        const result = await PaymentService.confirm(userid, params.id);
        broadcast(result.payment.bill_id, {
          type: "payment_confirmed",
          payment: result.payment,
          bill_settled: result.bill_settled,
        });
        return result;
      } catch (err: any) {
        return handleError(err, set);
      }
    },
    { params: PaymentIdParams, body: PaymentConfirmPayload },
  );
