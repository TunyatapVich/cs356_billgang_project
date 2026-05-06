import { Elysia } from "elysia";
import { jwt } from "@elysiajs/jwt";
import { BillCreatePayload, BillDeleteParams, BillModel } from "./model";
import { BillService } from "./service";

export const BillModule = new Elysia({ prefix: "/bills" })
  .use(BillModel)
  .use(jwt({ name: "jwt", secret: process.env.JWT_SECRET! }))

  .derive(async ({ jwt, headers }) => {
    const raw = headers.authorization?.replace("Bearer ", "");
    if (!raw) return { userid: null };

    const payload = await jwt.verify(raw);
    return { userid: payload?.sub ? (payload.sub as string) : null };
  })
  .get("/", async ({ userid }) => {
    const bills = await BillService.listBills(userid);
    return { bills };
  })

  .post(
    "/create",
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
        set.status = 409;
        return { message: err.message ?? "Create bill failed" };
      }
    },
    {
      body: BillCreatePayload,
      response: {
        201: "bills.create.response",
        401: "bills.create.error",
        409: "bills.create.error",
      },
    },
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
    {
      params: BillDeleteParams,
      response: {
        200: "bills.delete.response",
        401: "bills.delete.error",
        404: "bills.delete.error",
      },
    },
  );
