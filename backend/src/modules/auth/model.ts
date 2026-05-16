import Elysia, { t } from "elysia";
import { UsersPlain } from "../../../generated/prismabox/Users";
import { __nullable__ } from "../../../generated/prismabox/__nullable__";

const RegisterPayload = t.Object({
  email: t.String({ format: "email" }),
  display_name: t.Optional(__nullable__(t.String())),
  avatar_url: t.Optional(__nullable__(t.String())),
  promptpay_number: t.Optional(__nullable__(t.String())),
  password: t.String({ minLength: 8 }),
  password_confirm: t.String({ minLength: 8 }),
});

const LoginPayload = t.Object({
  email: t.String({ format: "email" }),
  password: t.String({ minLength: 8 }),
});

const AuthResponse = t.Object({
  token: t.String(),
  user: t.Omit(UsersPlain, ["password_hash"]),
});

const ProfileUpdatePayload = t.Object({
  display_name: t.Optional(__nullable__(t.String())),
  avatar_url: t.Optional(__nullable__(t.String())),
  avatar_file: t.Optional(t.File()),
  promptpay_number: t.Optional(__nullable__(t.String())),
});

const ErrorResponse = t.Object({ message: t.String() });

export const AuthModel = new Elysia({ name: "Model.Auth" }).model({
  "auth.register.request": RegisterPayload,
  "auth.login.request": LoginPayload,
  "auth.profile.update.request": ProfileUpdatePayload,
  "auth.response": AuthResponse,
  "auth.error": ErrorResponse,
});
