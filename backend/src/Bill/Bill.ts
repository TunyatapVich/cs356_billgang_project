import { Elysia, t } from "elysia";
import { PrismaNeon } from "@prisma/adapter-neon";
import { PrismaClient } from "../generated/prisma/client";

const databaseUrl = process.env.DATABASE_URL;

if (!databaseUrl) {
  throw new Error("DATABASE_URL is not set. Add it to backend/.env");
}

const adapter = new PrismaNeon({ connectionString: databaseUrl });
const prisma = new PrismaClient({ adapter });

export const billRoutes = new Elysia({ prefix: "/bills" })
  .get("/", async () => {
    return prisma.bills.findMany({
      orderBy: { created_at: "desc" },
    });
  })
  .get(
    "/:id",
    async ({ params, set }) => {
      const bill = await prisma.bills.findUnique({
        where: { id: params.id },
      });

      if (!bill) {
        set.status = 404;
        return { message: "Bill not found" };
      }

      return bill;
    },
    {
      params: t.Object({
        id: t.String(),
      }),
    }
  )
  .post(
    "/",
    async ({ body, set }) => {
      const bill = await prisma.bills.create({
        data: {
          name: body.name,
          date: new Date(body.date),
          created_by: body.created_by,
          status: body.status,
          invite_code: body.invite_code,
          receipt_image_url: body.receipt_image_url ?? null,
          service_charge_pct: body.service_charge_pct ?? null,
          vat_pct: body.vat_pct ?? null,
        },
      });

      set.status = 201;
      return bill;
    },
    {
      body: t.Object({
        name: t.String({ minLength: 1 }),
        date: t.String(),
        created_by: t.String(),
        status: t.String(),
        invite_code: t.String(),
        receipt_image_url: t.Optional(t.String()),
        service_charge_pct: t.Optional(t.Number()),
        vat_pct: t.Optional(t.Number()),
      }),
    }
  )
  .delete(
    "/:id",
    async ({ params, set }) => {
      try {
        await prisma.bills.delete({
          where: { id: params.id },
        });
        return { message: "Bill deleted" };
      } catch {
        set.status = 404;
        return { message: "Bill not found" };
      }
    },
    {
      params: t.Object({
        id: t.String(),
      }),
    }
  );