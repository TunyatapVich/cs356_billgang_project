// =============================================================================
// bills.ts — Create Bill Flow
// Covers: POST /bills  and  POST /bills/:id/items
//
// Sequence this file implements:
//   UI → POST /bills → DB INSERT bills → return {id, invite_code}
//   UI → POST /bills/:id/items → DB INSERT bill_items → return item
//
// Work through the TODOs top to bottom. Each one builds on the previous.
// When stuck, open a new chat and say the prompt shown in each TODO.
// =============================================================================

import Elysia, { t } from "elysia";
import { db } from "../db/client";

// =============================================================================
// TODO 1 — Understand the ElysiaJS plugin pattern
// =============================================================================
//
// In ElysiaJS, you don't write routes directly in index.ts.
// Instead, you create a mini Elysia app (called a "plugin") per feature,
// then register it in index.ts with .use(billsPlugin).
//
// Think of it like a router in Express:
//   Express:  app.use("/bills", billsRouter)
//   ElysiaJS: app.use(billsPlugin)   ← same idea, just named differently
//
// The .group("/bills") below means every route inside automatically
// starts with /bills — you don't repeat it on each route.
//
// 💬 Prompt: "I'm working on 3.1 Bill CRUD endpoints in ElysiaJS,
//             explain how the plugin and group pattern works"
//
// =============================================================================

export const billsPlugin = new Elysia()
  .group("/bills", (app) =>
    app

      // ===========================================================================
      // TODO 2 — Add JWT auth middleware BEFORE these routes
      // ===========================================================================
      //
      // Both routes below require a logged-in user. We need to:
      //   1. Read the "Authorization: Bearer <token>" header
      //   2. Verify the JWT signature
      //   3. Pull out the user's ID from the token payload
      //   4. Make that ID available inside the route as `userId`
      //
      // In ElysiaJS this is done with .derive() — it runs before every route
      // in this group and injects extra values into the request context.
      //
      // You will build the real auth middleware in task 2.2.
      // For now, leave a placeholder so the routes below can still compile.
      //
      // PLACEHOLDER (replace this in task 2.2):
      // .derive(({ headers, error }) => {
      //   const token = headers.authorization?.split(" ")[1];
      //   if (!token) return error(401, { message: "Missing token" });
      //   const payload = verifyJwt(token); // you'll write verifyJwt() in 2.2
      //   return { userId: payload.sub as string };
      // })
      //
      // 💬 Prompt: "I'm working on 2.2 JWT middleware in ElysiaJS, guide me"
      //
      // ===========================================================================

      // ===========================================================================
      // TODO 3 — POST /bills  (create a new bill)
      // ===========================================================================
      //
      // WHAT THIS ROUTE DOES:
      //   1. Validates the request body (ElysiaJS does this automatically
      //      using the `body: t.Object(...)` schema you define — see TODO 3a)
      //   2. Generates a unique invite_code for the bill
      //   3. Inserts a row into the `bills` table
      //   4. Inserts the creator into `bill_members` as role "owner"
      //   5. Returns the new bill to the UI
      //
      // WHY do we add the creator to bill_members?
      //   Because bill_members is how we know who is in a bill.
      //   The creator is also a member — just with role "owner" so they
      //   can manage it (delete items, close the bill, etc.)
      //
      // ===========================================================================
      .post(
        "/",
        async ({ body, error }) => {
          // TODO 3a — Read the validated body fields
          // ElysiaJS already checked that these exist and have the right types
          // (because of the `body` schema below). Just destructure them:
          //
          // const { name, date, service_charge_pct, vat_pct } = body;
          //
          // QUESTION: what is `service_charge_pct`? → the percentage added on top
          // of the subtotal (common in Thai restaurants, usually 10%).
          // It's optional — not every bill has it.

          // TODO 3b — Get the logged-in user's ID from the request context
          // After you add the middleware in TODO 2, you'll have `userId` available:
          //
          // const { userId } = context;  ← comes from .derive() in TODO 2
          //
          // For now, hardcode a fake UUID so you can test the route manually:
          const userId = "00000000-0000-0000-0000-000000000000"; // REMOVE LATER

          // TODO 3c — Generate a unique invite_code
          // The invite_code is what other users type or scan to join this bill.
          // It must be unique across all bills.
          //
          // Simplest option — use Node's built-in crypto (no package needed):
          //   const invite_code = crypto.randomUUID();
          //
          // Better option — a shorter, friendlier code with nanoid:
          //   import { nanoid } from "nanoid";
          //   const invite_code = nanoid(8);  // e.g. "aB3kZ9mQ"
          //
          // 💬 Prompt: "explain the difference between randomUUID and nanoid
          //             for invite codes, which should I use?"
          const invite_code = crypto.randomUUID(); // swap for nanoid later if you want

          // TODO 3d — Insert the bill into the database using Prisma
          //
          // Prisma's create() takes an object matching your schema fields.
          // Look at prisma/schema.prisma → model Bills to see all field names.
          //
          // const bill = await db.bills.create({
          //   data: {
          //     name,
          //     date: new Date(date),   // date comes in as a string, Prisma needs a Date
          //     created_by: userId,
          //     status: "draft",        // new bills start as draft
          //     invite_code,
          //     service_charge_pct: service_charge_pct ?? null,
          //     vat_pct: vat_pct ?? null,
          //   },
          // });
          //
          // QUESTION: why "draft" status?
          //   draft = bill is being built (items being added)
          //   open  = bill is shared, people are assigning
          //   settled = everyone paid
          //
          // 💬 Prompt: "I'm working on 3.1 Bill CRUD endpoints,
          //             show me how Prisma create() works"

          // TODO 3e — Add the creator as a bill member (role: "owner")
          //
          // We do this right after creating the bill so the creator
          // shows up in bill_members from the start.
          //
          // await db.billMembers.create({
          //   data: {
          //     bill_id: bill.id,
          //     user_id: userId,
          //     role: "owner",
          //   },
          // });

          // TODO 3f — Return the new bill to the UI
          //
          // The UI needs `id` (to make the next request to /bills/:id/items)
          // and `invite_code` (to show on the Invite screen later).
          //
          // IMPORTANT: Prisma Decimal fields (service_charge_pct, vat_pct)
          // are NOT plain numbers — they're Decimal objects. You must convert:
          //   Number(bill.service_charge_pct)
          // Otherwise JSON.stringify will break.
          //
          // return {
          //   id: bill.id,
          //   name: bill.name,
          //   invite_code: bill.invite_code,
          //   status: bill.status,
          //   service_charge_pct: bill.service_charge_pct ? Number(bill.service_charge_pct) : null,
          //   vat_pct: bill.vat_pct ? Number(bill.vat_pct) : null,
          //   created_at: bill.created_at.toISOString(),
          // };

          // TEMPORARY return — replace with the real one above once db is wired up
          return { message: "TODO: implement POST /bills" };
        },

        // TODO 3g — Define the request body schema
        //
        // ElysiaJS uses TypeBox (the `t` object) for validation.
        // If the client sends a body that doesn't match this schema,
        // ElysiaJS automatically returns a 422 error — you don't write
        // any if-statements for validation yourself.
        //
        // t.String()          → must be a string
        // t.Number()          → must be a number
        // t.Optional(...)     → field can be missing entirely
        // t.Nullable(...)     → field can be null
        //
        // Replace the placeholder schema below with the real one:
        {
          body: t.Object({
            name: t.String({ minLength: 1 }),
            date: t.String(), // ISO date string e.g. "2026-04-22"
            // TODO: add service_charge_pct and vat_pct as optional numbers (0–100)
            // Hint: t.Optional(t.Number({ minimum: 0, maximum: 100 }))
          }),
        }
      )

      // ===========================================================================
      // TODO 4 — POST /bills/:id/items  (add one item to a bill)
      // ===========================================================================
      //
      // WHAT THIS ROUTE DOES:
      //   1. Validates that the bill exists and the caller is a member
      //   2. Inserts a row into bill_items
      //   3. Returns the new item (UI uses this to confirm the optimistic update)
      //
      // WHAT IS OPTIMISTIC UPDATE?
      //   The Flutter UI shows the item immediately (before the server responds).
      //   If the server returns success → keep it shown.
      //   If the server returns an error → remove it (rollback).
      //
      //   This makes the app feel fast even over a slow network.
      //   The API's job is to respond quickly and accurately so the UI
      //   knows whether to keep or rollback.
      //
      // 💬 Prompt: "I'm working on 3.2 Bill items endpoints, guide me"
      //
      // ===========================================================================
      .post(
        "/:id/items",
        async ({ params, body, error }) => {
          const { id: billId } = params;

          // TODO 4a — Get the logged-in user's ID (same as TODO 3b)
          const userId = "00000000-0000-0000-0000-000000000000"; // REMOVE LATER

          // TODO 4b — Check the bill exists
          //
          // If someone sends a request with a fake bill ID, we should return 404.
          //
          // const bill = await db.bills.findUnique({ where: { id: billId } });
          // if (!bill) return error(404, { message: "Bill not found" });

          // TODO 4c — Check the caller is a member of this bill
          //
          // We don't want random users adding items to someone else's bill.
          //
          // const membership = await db.billMembers.findUnique({
          //   where: { bill_id_user_id: { bill_id: billId, user_id: userId } },
          // });
          // if (!membership) return error(403, { message: "Not a member of this bill" });
          //
          // QUESTION: what's that `bill_id_user_id` thing?
          //   Prisma auto-generates a compound key name for @@unique([bill_id, user_id]).
          //   The format is: fieldA_fieldB. You'll see it in the generated client types.

          // TODO 4d — Insert the item
          //
          // const { name, quantity, unit_price } = body;
          //
          // const item = await db.billItems.create({
          //   data: {
          //     bill_id: billId,
          //     name,
          //     quantity,
          //     unit_price,
          //   },
          // });

          // TODO 4e — Return the new item to the UI
          //
          // The UI needs the server-generated `id` so it can:
          //   - Replace the temporary optimistic ID with the real one
          //   - Send DELETE /bills/:id/items/:itemId later if needed
          //
          // return {
          //   id: item.id,
          //   bill_id: item.bill_id,
          //   name: item.name,
          //   quantity: item.quantity,
          //   unit_price: Number(item.unit_price),  // Decimal → number
          //   created_at: item.created_at.toISOString(),
          // };

          // TEMPORARY return
          return { message: "TODO: implement POST /bills/:id/items" };
        },

        // TODO 4f — Define the request body schema for items
        //
        // quantity must be at least 1 (you can't add 0 of something)
        // unit_price must be > 0 (free items don't need to be tracked)
        //
        {
          body: t.Object({
            name: t.String({ minLength: 1 }),
            quantity: t.Number({ minimum: 1 }),
            unit_price: t.Number({ exclusiveMinimum: 0 }),
          }),
          params: t.Object({
            id: t.String(), // the bill UUID from the URL
          }),
        }
      )
  );

// =============================================================================
// TODO 5 — Register this plugin in index.ts
// =============================================================================
//
// Open backend/src/index.ts and add:
//
//   import { billsPlugin } from "./routes/bills";
//
//   const app = new Elysia()
//     .use(billsPlugin)       // ← add this line
//     .get("/", () => "Hello Elysia")
//     .listen(3000);
//
// Then restart the dev server:
//   bun run dev
//
// Test with curl (or Postman / Hoppscotch):
//   curl -X POST http://localhost:3000/bills \
//     -H "Content-Type: application/json" \
//     -d '{"name":"Dinner","date":"2026-04-22"}'
//
// Expected: { "message": "TODO: implement POST /bills" }
// (until you wire up the real db logic)
//
// =============================================================================

// =============================================================================
// OVERALL ORDER TO WORK THROUGH
// =============================================================================
//
// 1. Complete db/client.ts TODO 0  → get Prisma connected
// 2. Complete TODO 3a–3f           → POST /bills works end-to-end
// 3. Complete TODO 4a–4e           → POST /bills/:id/items works
// 4. Complete TODO 5               → register plugin in index.ts
// 5. Move to task 2.2 in LEARNING_GUIDE to build real JWT middleware
//    then replace the hardcoded `userId` in TODO 3b and 4a
//
// =============================================================================
