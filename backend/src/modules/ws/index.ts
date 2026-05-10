import { Elysia, t } from "elysia";
import { jwt } from "@elysiajs/jwt";
import { WsBillService } from "./service";
import { setBroadcaster } from "../utils/broker";

type ServerWs = {
  send: (data: string) => void;
  close: (code?: number, reason?: string) => void;
  data: { params: { id: string }; userid: string | null };
};

const rooms = new Map<string, Set<ServerWs>>();

const join = (billId: string, ws: ServerWs) => {
  let set = rooms.get(billId);
  if (!set) {
    set = new Set();
    rooms.set(billId, set);
  }
  set.add(ws);
};

const leave = (billId: string, ws: ServerWs) => {
  const set = rooms.get(billId);
  if (!set) return;
  set.delete(ws);
  if (set.size === 0) rooms.delete(billId);
};

const broadcastToRoom = (billId: string, message: unknown, exclude?: ServerWs) => {
  const set = rooms.get(billId);
  if (!set) return;
  const payload = JSON.stringify(message);
  for (const client of set) {
    if (client === exclude) continue;
    try {
      client.send(payload);
    } catch {
      // ignore broken pipes
    }
  }
};

setBroadcaster((billId, message) => broadcastToRoom(billId, message));

const sendTo = (ws: ServerWs, message: unknown) => {
  try {
    ws.send(JSON.stringify(message));
  } catch {
    // ignore
  }
};

export const WsModule = new Elysia()
  .use(jwt({ name: "jwt", secret: process.env.JWT_SECRET! }))
  .ws("/ws/bills/:id", {
    params: t.Object({ id: t.String() }),
    query: t.Object({ token: t.Optional(t.String()) }),
    body: t.Any(),

    async open(ws) {
      const raw = (ws as any).data?.query?.token as string | undefined;
      const billId = (ws as any).data.params.id as string;
      const jwtUtil = (ws as any).data.jwt;

      const payload = raw ? await jwtUtil.verify(raw) : null;
      const userid = (payload?.sub as string | undefined) ?? null;
      if (!userid) {
        ws.send(JSON.stringify({ type: "error", message: "Unauthorized" }));
        ws.close(4401, "Unauthorized");
        return;
      }

      const isMember = await WsBillService.assertMember(userid, billId);
      if (!isMember) {
        ws.send(JSON.stringify({ type: "error", message: "Forbidden" }));
        ws.close(4403, "Forbidden");
        return;
      }

      (ws as any).data.userid = userid;
      join(billId, ws as unknown as ServerWs);

      const snapshot = await WsBillService.getSnapshot(billId);
      sendTo(ws as unknown as ServerWs, { type: "sync", ...snapshot });
    },

    async message(ws, raw) {
      const billId = (ws as any).data.params.id as string;
      const userid = (ws as any).data.userid as string | null;
      if (!userid) {
        ws.send(JSON.stringify({ type: "error", message: "Unauthorized" }));
        return;
      }

      const msg = raw as { type?: string; payload?: any };
      if (!msg || typeof msg.type !== "string") {
        sendTo(ws as unknown as ServerWs, { type: "error", message: "Invalid message" });
        return;
      }

      try {
        switch (msg.type) {
          case "sync_request": {
            const snap = await WsBillService.getSnapshot(billId);
            sendTo(ws as unknown as ServerWs, { type: "sync", ...snap });
            break;
          }
          case "add_item": {
            const item = await WsBillService.addItem(billId, msg.payload);
            broadcastToRoom(billId, { type: "item_added", item });
            break;
          }
          case "remove_item": {
            const ok = await WsBillService.removeItem(billId, msg.payload?.item_id);
            if (ok) broadcastToRoom(billId, { type: "item_removed", item_id: msg.payload.item_id });
            break;
          }
          case "assign_item": {
            const assign = await WsBillService.assignItem(
              msg.payload?.item_id,
              msg.payload?.user_id ?? userid,
            );
            broadcastToRoom(billId, { type: "item_assigned", assign });
            break;
          }
          case "unassign_item": {
            const userId = msg.payload?.user_id ?? userid;
            const itemId = msg.payload?.item_id;
            const ok = await WsBillService.unassignItem(itemId, userId);
            if (ok) {
              broadcastToRoom(billId, {
                type: "item_unassigned",
                assign: { bill_item_id: itemId, user_id: userId },
              });
            }
            break;
          }
          default:
            sendTo(ws as unknown as ServerWs, { type: "error", message: `Unknown type: ${msg.type}` });
        }
      } catch (err: any) {
        sendTo(ws as unknown as ServerWs, {
          type: "error",
          message: err?.message ?? "Server error",
        });
      }
    },

    close(ws) {
      const billId = (ws as any).data?.params?.id as string | undefined;
      if (billId) leave(billId, ws as unknown as ServerWs);
    },
  });
