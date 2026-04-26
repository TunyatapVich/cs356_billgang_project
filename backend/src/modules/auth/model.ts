// Model define the data structure and validation for the request and response
import Elysia, { t, type UnwrapSchema } from "elysia";
import {
  Users,
  UsersPlain,
  UsersPlainInputCreate,
} from "../../../generated/prismabox/Users";
import { __nullable__ } from "../../../generated/prismabox/__nullable__";

const RegisterPayload = t.Object({
  email: t.String(),
  display_name: t.Optional(__nullable__(t.String())),
  avatar_url: t.Optional(__nullable__(t.String())),
  promptpay_number: t.Optional(__nullable__(t.String())),
  password: t.String({ minLength: 8 }),
  password_confirm: t.String({ minLength: 8 }),
});

export const AuthModel = new Elysia({ name: "Model.Auth" }).model({
  "auth.register.request": RegisterPayload,
  "auth.register.response": t.Omit(UsersPlain, ["password_hash"]),
});
