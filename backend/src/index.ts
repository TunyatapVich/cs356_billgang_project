import { Elysia } from "elysia";
import { openapi } from "@elysiajs/openapi";
import { billRoutes } from "./Bill/Bill";

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
    })
  )
  .use(billRoutes)
  .get("/", () => "Hello Elysia - OpenAPI at /docs")
  .listen(3000);

console.log(
  `🦊 Elysia is running at ${app.server?.hostname}:${app.server?.port}`
);
