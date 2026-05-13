import { Elysia } from "elysia";
import {
  PaymentConfirmPayload,
  PaymentCreatePayload,
  PaymentIdParams,
  PaymentListQuery,
  PaymentModel,
} from "./model";
import { PaymentService } from "./service";
import { authPlugin } from "../utils/auth";
import { broadcast } from "../utils/broker";
import { uploadImage } from "../utils/storage";

const handleError = (err: any, set: any) => {
  if (err?.message === "FORBIDDEN") {
    set.status = 403;
    return { message: "Forbidden" };
  }
  if (err?.message === "NOT_FOUND" || err?.message === "RECIPIENT_NOT_FOUND") {
    set.status = 404;
    return { message: "Not found" };
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

  .put(
    "/:id/confirm",
    async ({ params, body, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        let slipUrl: string | undefined;
        if (body.slip) {
          slipUrl = await uploadImage(
            await body.slip.arrayBuffer(),
            body.slip.type || "image/jpeg",
          );
        }
        const result = await PaymentService.confirm(userid, params.id, slipUrl);
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
