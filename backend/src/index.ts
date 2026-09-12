import "./env";
import { Elysia } from "elysia";
import { cors } from "@elysiajs/cors";
import { openapi } from "@elysiajs/openapi";
import { AuthModule } from "./modules/auth";
import { BillModule } from "./modules/bills";
import { PaymentModule } from "./modules/payments";
import { UsersModule } from "./modules/users";
import { WsModule } from "./modules/ws";

const app = new Elysia()
  .use(
    cors({
      origin: true,
      methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
      allowedHeaders: ["Content-Type", "Authorization"],
      credentials: true,
    }),
  )
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
  .use(UsersModule)
  .use(WsModule)
  .get("/", () => "Hello Elysia - API docs at /docs")
  .listen({
    port: Number(process.env.PORT) || 3000,
    hostname: "0.0.0.0",
  });

console.log(
  `🦊 Elysia is running at ${app.server?.hostname}:${app.server?.port}`,
);
