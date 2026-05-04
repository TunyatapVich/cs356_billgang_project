import { Elysia } from "elysia";
import { jwt } from "@elysiajs/jwt";
import { BillCreatePayload, BillModel } from "./model";
import { BillService } from "./service";

export const BillModule = new Elysia({ prefix: "/bills" })
  .use(BillModel)
  .use(jwt({ name: "jwt", secret: process.env.JWT_SECRET! }))

  .derive(async ({ jwt, set, headers }) => {
    const raw = headers.authorization?.replace("Bearer ", "");
    const payload = await jwt.verify(raw!);
    if (!payload) {
      set.status = 401;
      throw new Error("Unauthorized");
    }
    return { userid: payload.sub as string };
  })
    
    .post(
        "/create",
        async ({ body, set, userid }) => {
            try {
                const bill = await BillService.createBill(userid, body);
                
                set.status = 201;
                return { bill };
            } catch (err: any) {
                set.status = 409;
                return { message: err.message ?? "Registration failed" };
            }
        },
        {
            body: BillCreatePayload,
            response: {
                201: "bills.create.response",
                409: "bills.create.error"
            }
        }
    )

    

    .delete(
        "/:id",
        async ({ params, jwt, set }) => { delete params.id; },
        {
            response: {
                200: "bills.delete.response",
                404: "bills.delete.error"
            }
        }
    )
