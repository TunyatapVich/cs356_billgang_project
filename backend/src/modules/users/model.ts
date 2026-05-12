import Elysia, { t } from "elysia";

const UserStatsResponse = t.Object({
  total_paid: t.Number(),
  total_received: t.Number(),
  bills_count: t.Integer(),
  bills_owned: t.Integer(),
});

const UserPartnersResponse = t.Object({
  partners: t.Array(
    t.Object({
      user_id: t.String(),
      display_name: t.Nullable(t.String()),
      avatar_url: t.Nullable(t.String()),
      total_paid_to: t.Number(),
    }),
  ),
});

export const UsersModel = new Elysia({ name: "Model.Users" }).model({
  "users.stats.response": UserStatsResponse,
  "users.partners.response": UserPartnersResponse,
});
