import { Elysia } from "elysia";
import { jwt } from "@elysiajs/jwt";
import { AuthModel } from "./model";
import { AuthService, GoogleAuthError } from "./service";
import { authPlugin } from "../utils/auth";
import { uploadImage } from "../utils/storage";

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
        if (err?.code === "P2002" || err?.message === "Email already registered") {
          set.status = 409;
          return { message: "Email already registered" };
        }
        set.status = 500;
        return { message: "Registration failed" };
      }
    },
    {
      body: "auth.register.request",
      response: {
        201: "auth.response",
        400: "auth.error",
        409: "auth.error",
        500: "auth.error",
      },
    },
  )

  .post(
    "/google",
    async ({ body, jwt, set }) => {
      try {
        const user = await AuthService.loginWithGoogle(body.id_token);
        const token = await jwt.sign({ sub: user.id });
        return { token, user };
      } catch (err) {
        if (err instanceof GoogleAuthError) {
          set.status = err.status;
          return { message: err.message };
        }
        console.error("[auth/google] sign-in failed", err);
        set.status = 500;
        return { message: "Google sign-in failed" };
      }
    },
    {
      body: "auth.google.request",
      response: {
        200: "auth.response",
        401: "auth.error",
        500: "auth.error",
        503: "auth.error",
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
        let finalAvatarUrl = body.avatar_url;
        if (body.avatar_file) {
          finalAvatarUrl = await uploadImage(
            await body.avatar_file.arrayBuffer(),
            body.avatar_file.type || "image/jpeg",
            "avatars"
          );
        }

        const user = await AuthService.updateProfile(userid, {
          display_name: body.display_name,
          avatar_url: finalAvatarUrl,
          promptpay_number: body.promptpay_number,
        });
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
