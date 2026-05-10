import { Elysia } from "elysia";
import { jwt } from "@elysiajs/jwt";
import { AuthModel } from "./model";
import { AuthService } from "./service";
import { authPlugin } from "../utils/auth";

export const AuthModule = new Elysia({ prefix: "/auth" })
  .use(AuthModel)
  .use(jwt({ name: "jwt", secret: process.env.JWT_SECRET! }))

  .post(
    "/register",
    async ({ body, jwt, set }) => {
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
      const user = await AuthService.loginUser(body);
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

  .use(authPlugin)

  .get(
    "/me",
    async ({ userid, headers, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "go login bro" };
      }
      const user = await AuthService.getMe(userid);
      if (user === "not found" || !user) {
        set.status = 404;
        return { message: "User not found" };
      }
      const raw = headers.authorization?.replace("Bearer ", "") ?? "";
      return { token: raw, user };
    },
    {
      response: {
        200: "auth.response",
        401: "auth.error",
        404: "auth.error",
      },
    },
  )

  .put(
    "/profile",
    async ({ body, jwt, userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      try {
        const user = await AuthService.updateProfile(userid, body);
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
