import { Elysia } from "elysia";
import { jwt } from "@elysiajs/jwt";

export const authPlugin = new Elysia({ name: "auth-plugin" })
  .use(jwt({ name: "jwt", secret: process.env.JWT_SECRET! }))
  .derive(
    { as: "scoped" },
    async ({ jwt, headers, query }) => {
      const headerToken = headers.authorization?.replace("Bearer ", "");
      const queryToken = (query as Record<string, string | undefined>)?.token;
      const raw = headerToken ?? queryToken;
      const payload = raw ? await jwt.verify(raw) : null;
      return { userid: (payload?.sub as string | undefined) ?? null };
    },
  );
