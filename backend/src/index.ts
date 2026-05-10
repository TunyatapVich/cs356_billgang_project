import { Elysia } from "elysia";
import { openapi } from "@elysiajs/openapi";
import { AuthModule } from "./modules/auth";
import { BillModule } from "./modules/bills";
import { PaymentModule } from "./modules/payments";
import { WsModule } from "./modules/ws";

const app = new Elysia()
  .use(
    openapi({
      path: "/docs",
      provider: "scalar",
      documentation: {
        info: {
          title: "BillGang API",
          version: "1.0.0",
          description: "API docs for BillGang backend",
        },
      },
    }),
  )

  .use(AuthModule)
  .use(BillModule)
  .use(PaymentModule)
  .use(WsModule)
  .get("/", () => "Hello Elysia - API docs at /docs")
  .listen(3000);

console.log(
  `🦊 Elysia is running at ${app.server?.hostname}:${app.server?.port}`,
);
