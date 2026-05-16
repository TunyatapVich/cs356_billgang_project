import { Elysia } from "elysia";
import { UsersModel } from "./model";
import { UserStatsService } from "./service";
import { authPlugin } from "../utils/auth";

export const UsersModule = new Elysia({ prefix: "/users" })
  .use(UsersModel)
  .use(authPlugin)

  .get(
    "/me/stats",
    async ({ userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      return await UserStatsService.getStats(userid);
    },
  )

  .get(
    "/me/partners",
    async ({ userid, set }) => {
      if (!userid) {
        set.status = 401;
        return { message: "Unauthorized" };
      }
      return await UserStatsService.getPartners(userid);
    },
  );
