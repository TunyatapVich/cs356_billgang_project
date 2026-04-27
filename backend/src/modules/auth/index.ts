import { Elysia, t } from "elysia";
import { AuthModel } from "./model";
import { registerUser } from "./service";

export const AuthModule = new Elysia({ prefix: "/auth" }).use(AuthModel).post(
  "/register",
  async ({ body, set }) => {
    if (body.password !== body.password_confirm) {
      set.status = 400;
      return { message: "Password do not match" };
    }

    const user = await registerUser(body);
    set.status = 201;
    return user;
  },
  {
    body: "auth.register.request",
    response: {
      "201": "auth.register.response",
      "400": t.Object({
        message: t.String(),
      }),
    },
  },
);
