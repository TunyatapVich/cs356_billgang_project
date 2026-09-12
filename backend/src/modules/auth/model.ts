import Elysia, { t } from "elysia";
import { UsersPlain } from "../../../generated/prismabox/Users";
import { __nullable__ } from "../../../generated/prismabox/__nullable__";

const Password = t.String({ minLength: 8 });

const RegisterPayload = t.Object({
  email: t.String({ format: "email" }),
  display_name: t.Optional(__nullable__(t.String())),
  avatar_url: t.Optional(__nullable__(t.String())),
  promptpay_number: t.Optional(__nullable__(t.String())),
  password: Password,
  password_confirm: Password,
});

const LoginPayload = t.Object({
  email: t.String({ format: "email" }),
  password: Password,
});

const GoogleLoginPayload = t.Object({
  id_token: t.String({ minLength: 1 }),
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
  "auth.google.request": GoogleLoginPayload,
  "auth.profile.update.request": ProfileUpdatePayload,
  "auth.response": AuthResponse,
  "auth.error": ErrorResponse,
});
