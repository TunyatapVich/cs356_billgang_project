import { Elysia, t } from "elysia";
import { jwt } from "@elysiajs/jwt";
import { AuthModel } from "./model";
import { AuthService } from "./service";

export const AuthModule = new Elysia({ prefix: "/auth" })
  .use(AuthModel)
  .use(jwt({ name: "jwt", secret: process.env.JWT_SECRET! }))

  .post(
    "/register",
    async ({ body , jwt , set }) => {
      if (body.password !== body.password_confirm) {
        set.status = 400;
        return { message: "Passwords do not match" };
      }
      try {
        const user = await AuthService.registerUser(body);
        const token = await jwt.sign({ sub: user.id });
        set.status = 201;
        return { token, user };
      } catch (err: any) {
        set.status = 409;
        return { message: err.message ?? "Registration failed" };
      }
    },
    {
      body: "auth.register.request",
      response: {
        201: "auth.response",
        400: "auth.error",
        409: "auth.error",
      },
    },
  )

  .post(
    "/login",
    async ({ body, jwt, set }) => {
      const user = await AuthService.loginUser(body.email, body.password);
      if (!user) {
        set.status = 401;
        return { message: "Invalid email or password" };
      }
      const token = await jwt.sign({ sub: user.id });
      return { token, user };
    },
    {
      body: "auth.login.request",
      response: {
        200: "auth.response",
        401: "auth.error",
      },
    },
  )

  .put(
    "/profile",
    async ({ body, jwt, headers, set }) => {
      const raw = headers.authorization?.replace("Bearer ", "");
      const payload = raw ? await jwt.verify(raw) : null;
      if (!payload?.sub) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        const user = await AuthService.updateProfile(payload.sub as string, body);
        const token = await jwt.sign({ sub: user.id });
        return { token, user };
      } catch (err: any) {
        set.status = 400;
        return { message: err.message ?? "Update failed" };
      }
    },
    {
      body: "auth.profile.update.request",
      response: {
        200: "auth.response",
        400: "auth.error",
        401: "auth.error",
      },
    },
  );
