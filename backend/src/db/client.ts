// =============================================================================
// TODO 0 — Understand this file before touching bills.ts
// =============================================================================
//
// WHY THIS FILE EXISTS
// --------------------
// Prisma needs a "client" object to talk to the database.
// If we create `new PrismaClient()` inside every route file, we'd open a new
// database connection pool every time — wasteful and buggy.
//
// The fix: create ONE client and export it. Every file imports the same object.
// This pattern is called a "singleton".
//
// WHAT YOU NEED TO DO
// -------------------
// Step 1: Make sure your .env file exists at backend/.env with:
//         DATABASE_URL="postgresql://..."   ← copy from your Neon dashboard
//
// Step 2: Run the Prisma migration to create the tables in your real DB:
//         bun --bun run prisma migrate dev --name init
//
//         "migrate dev" does two things:
//           a) creates the SQL file in prisma/migrations/
//           b) runs it against your Neon database
//
// Step 3: Generate the Prisma client (TypeScript types from your schema):
//         bun --bun run prisma generate
//
//         After this, the import below will work without errors.
//
// QUESTION TO THINK ABOUT
// -----------------------
// Why do we put `db` in its own file instead of just writing it in index.ts?
// → Because bills.ts, auth.ts, and future route files all need `db`.
//   If it lived in index.ts you'd have a circular import. Separate file = clean.
//
// =============================================================================

import { PrismaClient } from "../generated/prisma";

export const db = new PrismaClient();
