# SplitBill — CLAUDE.md

## What is this project?

SplitBill (BillGang) is a mobile app for splitting restaurant bills among friends.
A user creates a bill, invites friends, and everyone assigns themselves to the items they ate in real-time. The app then calculates the minimum number of transfers needed and generates a PromptPay QR code for each payment.

Built as a CS356 Mobile Application Development project at Bangkok University.

## Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Mobile | Flutter (Dart) + Riverpod | Cross-platform, Riverpod for lightweight state management |
| Backend | ElysiaJS on Bun | Business logic: debt algorithm, OCR parsing, QR generation |
| Database | Neon (PostgreSQL) | Serverless Postgres, free tier sufficient for student project |
| Real-time | WebSocket via ElysiaJS | Bidirectional — needed for collaborative item assign screen |
| Auth | Firebase Auth | Email/password + Google Sign-In |
| OCR | Google ML Kit (on-device) + LLM API | ML Kit extracts raw text, LLM structures it into items |
| Payment | PromptPay QR (EMVCo CRC-16) | Thai standard, scannable by all banking apps |

## Database Schema (key tables)

- `users` — display_name, promptpay_number, avatar_url
- `bills` — name, date, created_by, status, service_charge_pct, vat_pct, invite_code
- `bill_items` — bill_id, name, quantity, unit_price
- `bill_members` — bill_id, user_id, role (owner | member)
- `item_assigns` — bill_item_id, user_id (junction — supports shared items)
- `payments` — bill_id, from_user_id, to_user_id, amount, status, slip_url

## Key Features

1. **Real-time collaborative assign** — multiple users add items and assign themselves simultaneously via WebSocket; all see each other's changes live
2. **OCR receipt scanner** — camera → ML Kit on-device OCR → LLM parses raw text into structured items → user reviews before saving
3. **Debt simplification** — min-cash-flow algorithm reduces N*(N-1) possible transfers to the minimum needed
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

1. **Auth** — Register / Google Sign-In / Setup Profile
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

## Team (5 members)

1. ธัญเทพ วิชัยดิษ — 1660702182
2. สิทธินันท์ แดงมะแจ้ง — 1660702976
3. ชยานันต์ ปทุมารักษ์ — 1660703537
4. จีระเดช มักเจริญ — 1660703214
5. อภิสิทธิ์ ด่านเจ้าแดง — 1660706803

## Docs in this repo

- `SplitBill_ProjectPlan.md` — module breakdown with dependency order
- `SplitBill_Screens.md` / `.xlsx` — all 16 screens with assignment table
- `SplitBill_ERDiagram.mermaid` — database ER diagram
- `diagrams/` — 6 sequence diagrams (one per user flow)
