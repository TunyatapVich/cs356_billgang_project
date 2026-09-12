import { PrismaNeon } from "@prisma/adapter-neon";
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "./generated/prisma/index.js";
import { Pool } from "pg";

import { config } from "dotenv";
config({ path: "../.env", quiet: true });
config({ quiet: true });

const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  throw new Error("DATABASE_URL is required");
}

const adapter = /neon\.(tech|build)/i.test(connectionString)
  ? new PrismaNeon({ connectionString })
  : new PrismaPg(new Pool({ connectionString }));

export const prisma = new PrismaClient({ adapter });
