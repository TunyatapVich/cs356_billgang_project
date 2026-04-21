# SplitBill — CLAUDE.md

## What is this project?

SplitBill (BillGang) is a mobile app for splitting restaurant bills among friends.
A user creates a bill, invites friends, and everyone assigns themselves to the items they ate in real-time. The app then calculates the minimum number of transfers needed and generates a PromptPay QR code for each payment.

Built as a CS356 Mobile Application Development project at Bangkok University.

## Tech Stack

| Layer     | Technology                          | Why                                                           |
| --------- | ----------------------------------- | ------------------------------------------------------------- |
| Mobile    | Flutter (Dart) + Riverpod           | Cross-platform, Riverpod for lightweight state management     |
| Backend   | ElysiaJS on Bun                     | Business logic: debt algorithm, OCR parsing, QR generation    |
| ORM       | Prisma 7 + Prismabox                | Prisma for type-safe DB access; Prismabox generates TypeBox schemas from Prisma models for ElysiaJS route validation |
| Database  | Neon (PostgreSQL)                   | Serverless Postgres, free tier sufficient for student project |
| Real-time | WebSocket via ElysiaJS              | Bidirectional — needed for collaborative item assign screen   |
| Auth      | JWT + bcrypt                        | Email/password only — bcrypt hash stored in DB, JWT issued on login |
| OCR       | Google ML Kit (on-device) + LLM API | ML Kit extracts raw text, LLM structures it into items        |
| Payment   | PromptPay QR (EMVCo CRC-16)         | Thai standard, scannable by all banking apps                  |

## Database Schema (key tables)

Defined in `backend/prisma/schema.prisma`. All IDs are UUIDs.

- `users` — id, email, password_hash, display_name, promptpay_number, avatar_url, created_at
- `bills` — id, name, date, created_by, status (`draft`|`open`|`settled`), receipt_image_url, service_charge_pct, vat_pct, invite_code (unique), created_at
- `bill_items` — id, bill_id, name, quantity, unit_price (Decimal 12,2), created_at
- `bill_members` — id, bill_id, user_id, role (`owner`|`member`), joined_at; unique(bill_id, user_id)
- `item_assigns` — id, bill_item_id, user_id, assigned_at; unique(bill_item_id, user_id)
- `payments` — id, bill_id, from_user_id, to_user_id, amount, status (`pending`|`confirmed`), slip_url, created_at

All child tables cascade delete from parent. Indexes on all foreign keys.

## Key Features

1. **Real-time collaborative assign** — multiple users add items and assign themselves simultaneously via WebSocket; all see each other's changes live
2. **OCR receipt scanner** — camera → ML Kit on-device OCR → LLM parses raw text into structured items → user reviews before saving
3. **Debt simplification** — min-cash-flow algorithm reduces N\*(N-1) possible transfers to the minimum needed
4. **PromptPay QR** — generated server-side per payment, pre-filled with correct amount

## Architecture

```
Flutter (Riverpod)
    │
    ├── HTTP ──► ElysiaJS API ──► Neon PostgreSQL
    │               │
    └── WS ─────────┘  (real-time assign screen only)
```

ElysiaJS handles all business logic. Flutter reads/writes via REST for most flows and WebSocket only for the real-time assign screen.

## User Flows (6 total)

1. **Auth** — Register (email + password) / Login / Setup Profile
2. **Create Bill** — name, date, add items manually
3. **OCR** — scan receipt → review parsed items → save
4. **Invite & Join** — QR code / deep link → join bill
5. **Real-time Assign** — WebSocket room, add items + assign simultaneously
6. **Debt & Settle** — debt simplification → PromptPay QR → upload slip → confirm

## Screens (16 total)

S01 Splash · S02 Login · S03 Register · S04 Setup Profile ·
S05 Home (bill list) · S06 Create Bill · S07 OCR Scanner · S08 OCR Review ·
S09 Invite Friends · S10 Assign Menu (real-time) ·
S11 Bill Summary App View · S12 Bill Summary Receipt View ·
S13 Debt Summary · S14 Bill Per Person · S15 PromptPay QR · S16 Profile

## Current Implementation State

Both apps are at **scaffold only** — no features implemented yet.

- `backend/src/index.ts` — bare `Hello Elysia` on port 3000
- `frontend/lib/main.dart` — default Flutter counter app
- Prisma schema is complete (`backend/prisma/schema.prisma`) but not yet migrated
- Flutter `pubspec.yaml` has no app dependencies yet (Riverpod, GoRouter, Firebase, etc. still to be added)

Current active branch: `feat/backend-create-bill-flow` — backend being built first.

## Dev Commands

```bash
# Backend
cd backend
bun run dev                              # start with hot-reload (watch mode)
bun --bun run prisma migrate dev         # run migrations against Neon
bun --bun run prisma generate            # regenerate Prisma client + Prismabox types

# Frontend
cd frontend
flutter pub get                          # install dependencies
flutter run                              # run on connected device / emulator
```

## Environment Variables

Backend reads from `.env` (not committed). Required:

```
DATABASE_URL=postgresql://...           # Neon connection string (from Neon dashboard)
```

`prisma.config.ts` reads `DATABASE_URL` via `env()` — Prisma will error without it.

## Flutter Folder Structure

Feature-first with Clean Architecture layers. See `frontend/docs/flutter_folder_structure.md` for the full tree.

```
lib/
├── core/          # Shared: constants, network client, shared widgets
├── features/      # One folder per feature (auth, bill, assign, payment…)
│   └── <feature>/
│       ├── data/         # datasources, models (fromJson/toJson), repo impl
│       ├── domain/       # entities, abstract repo interface, usecases
│       └── presentation/ # notifier/provider, pages, feature-specific widgets
└── main.dart
```

Rule: widgets never call the API directly — always go through the state layer.

## Backend Folder Structure (planned)

```
backend/src/
├── index.ts           # app entry, plugin registration
├── routes/            # one file per resource (bills.ts, auth.ts, …)
├── services/          # business logic (debt algorithm, QR gen, OCR parsing)
├── db/                # Prisma client singleton
└── generated/prisma/  # auto-generated Prisma client (gitignored)
```

## Prismabox

`prismabox` is a Prisma generator that outputs TypeBox (`t.*`) schemas matching each Prisma model. Run `bun --bun run prisma generate` to regenerate. Import from `generated/prismabox/` in route files to get type-safe request/response validation in ElysiaJS without writing schemas by hand.

## Gotchas

- No Firebase — auth is email/password only. Hash with bcrypt on register, verify on login, return a JWT. Never store plaintext passwords.
- `LEARNING_GUIDE.md` mentions Drizzle ORM — **ignore this**, the project uses Prisma. Drizzle was an earlier plan.
- `prisma-adapter-bun-sqlite` appears in `package.json` dependencies but the datasource is PostgreSQL — this is a leftover and can be removed.
- Prisma decimal fields (`unit_price`, `amount`, `service_charge_pct`, `vat_pct`) come back as `Decimal` objects from the client — serialize to `Number` or `string` before sending JSON responses.
- `invite_code` on bills must be unique and URL-safe — generate with `crypto.randomUUID()` or a short nanoid.

## Docs in this repo

- `SplitBill_ProjectPlan.md` — module breakdown with dependency order
- `SplitBill_Screens.md` / `.xlsx` — all 16 screens with assignment table
- `SplitBill_ERDiagram.mermaid` — database ER diagram
- `diagrams/` — 6 sequence diagrams (one per user flow)
- `frontend/docs/flutter_folder_structure.md` — feature-first folder structure guide
- `LEARNING_GUIDE.md` — task checklist for teaching mode (note: references Drizzle, use Prisma instead)
