# SplitBill — Junior Dev Learning Guide

> **How to use this guide**
> Work through each task in order. When you're ready to start a task, open a new chat and say:
> **"I'm working on [task name], guide me through it"**
> Claude will walk you through it step-by-step in teaching mode — ask questions before giving answers.
>
> Say **"just tell me"** anytime you're on a deadline and need the answer fast.

---

## Phase 1 — Project Setup
*Goal: get both repos running locally before writing any feature code*

### Backend (ElysiaJS)

- [ ] **1.1 Init the ElysiaJS project**
  - 🎯 *You'll learn:* what Bun is and why it's faster than Node, how ElysiaJS differs from Express
  - 💬 Prompt: `"I'm working on 1.1 Init ElysiaJS project, guide me through it"`

- [ ] **1.2 Connect Neon PostgreSQL with Drizzle ORM**
  - 🎯 *You'll learn:* what an ORM does, why Drizzle over Prisma for Bun, how connection strings work
  - 💬 Prompt: `"I'm working on 1.2 Connect Neon with Drizzle ORM, guide me through it"`

- [ ] **1.3 Write the database schema in Drizzle**
  - 🎯 *You'll learn:* how to translate an ER diagram into code, what migrations are and why they matter
  - 💬 Prompt: `"I'm working on 1.3 Write DB schema in Drizzle, guide me through it"`

- [ ] **1.4 Set up folder structure and middleware**
  - 🎯 *You'll learn:* separation of concerns (routes vs services vs db), what CORS is and why you need it
  - 💬 Prompt: `"I'm working on 1.4 ElysiaJS folder structure and middleware, guide me through it"`

### Frontend (Flutter)

- [ ] **1.5 Init Flutter project and set up folder structure**
  - 🎯 *You'll learn:* feature-based folder structure vs layer-based, why it matters at scale
  - 💬 Prompt: `"I'm working on 1.5 Flutter project setup and folder structure, guide me through it"`

- [ ] **1.6 Set up Riverpod**
  - 🎯 *You'll learn:* what state management is, why you need it, how Riverpod's Provider works
  - 💬 Prompt: `"I'm working on 1.6 Setting up Riverpod, guide me through it"`

- [ ] **1.7 Set up GoRouter for navigation**
  - 🎯 *You'll learn:* declarative vs imperative routing, route guards for auth
  - 💬 Prompt: `"I'm working on 1.7 GoRouter navigation setup, guide me through it"`

- [ ] **1.8 Create a base design system (theme, colors, text styles)**
  - 🎯 *You'll learn:* why you define design tokens once instead of hardcoding colors everywhere
  - 💬 Prompt: `"I'm working on 1.8 Flutter design system, guide me through it"`

---

## Phase 2 — Auth (S02, S03, S04)
*Goal: a user can register, log in, and set up their profile*

- [ ] **2.1 Build POST /auth/register and POST /auth/login in ElysiaJS**
  - 🎯 *You'll learn:* password hashing (bcrypt), JWT — what it is, how it's signed, what goes in the payload
  - 💬 Prompt: `"I'm working on 2.1 Auth endpoints in ElysiaJS, guide me through it"`

- [ ] **2.2 Build auth middleware (JWT verification)**
  - 🎯 *You'll learn:* middleware pattern, how every protected route reads the token
  - 💬 Prompt: `"I'm working on 2.2 JWT middleware in ElysiaJS, guide me through it"`

- [ ] **2.3 Integrate Firebase Auth (Google Sign-In) on Flutter**
  - 🎯 *You'll learn:* OAuth flow, what an idToken is and why you verify it server-side
  - 💬 Prompt: `"I'm working on 2.3 Google Sign-In in Flutter, guide me through it"`

- [ ] **2.4 Build Login and Register screens (S02, S03)**
  - 🎯 *You'll learn:* Form validation in Flutter, TextFormField, how to show errors properly
  - 💬 Prompt: `"I'm working on 2.4 Login and Register screens in Flutter, guide me through it"`

- [ ] **2.5 Build Setup Profile screen (S04)**
  - 🎯 *You'll learn:* ImagePicker, uploading files to an API, optimistic UI
  - 💬 Prompt: `"I'm working on 2.5 Setup Profile screen in Flutter, guide me through it"`

- [ ] **2.6 Persist auth state (secure token storage + route guard)**
  - 🎯 *You'll learn:* flutter_secure_storage, how a splash screen checks token and redirects
  - 💬 Prompt: `"I'm working on 2.6 Auth state persistence in Flutter, guide me through it"`

---

## Phase 3 — Core Bill Flow (S05, S06, S09)
*Goal: user can create a bill, add items, and invite friends*

- [ ] **3.1 Build bill CRUD endpoints (POST, GET, PUT /bills)**
  - 🎯 *You'll learn:* RESTful resource design, what makes a good API response shape
  - 💬 Prompt: `"I'm working on 3.1 Bill CRUD endpoints in ElysiaJS, guide me through it"`

- [ ] **3.2 Build bill items endpoints (POST, PUT, DELETE /bills/:id/items)**
  - 🎯 *You'll learn:* nested resources in REST, when to batch vs single insert
  - 💬 Prompt: `"I'm working on 3.2 Bill items endpoints, guide me through it"`

- [ ] **3.3 Build Home screen — bill list (S05)**
  - 🎯 *You'll learn:* ListView, pull-to-refresh, loading/error/empty states
  - 💬 Prompt: `"I'm working on 3.3 Home screen bill list in Flutter, guide me through it"`

- [ ] **3.4 Build Create Bill screen (S06)**
  - 🎯 *You'll learn:* dynamic list (add/remove rows), DatePicker, optimistic update pattern
  - 💬 Prompt: `"I'm working on 3.4 Create Bill screen in Flutter, guide me through it"`

- [ ] **3.5 Build invite system (generate code + join endpoint)**
  - 🎯 *You'll learn:* how short invite codes work, deep links on mobile (uni_links package)
  - 💬 Prompt: `"I'm working on 3.5 Invite system, guide me through it"`

- [ ] **3.6 Build Invite Friends screen (S09)**
  - 🎯 *You'll learn:* QR code generation in Flutter, Share sheet, deep link handling
  - 💬 Prompt: `"I'm working on 3.6 Invite Friends screen, guide me through it"`

---

## Phase 4 — Real-time Assign (S10) ⭐
*The hardest part — take your time here*

- [ ] **4.1 Set up WebSocket server in ElysiaJS (room-based)**
  - 🎯 *You'll learn:* how WebSocket differs from HTTP, pub/sub pattern, what a "room" means
  - 💬 Prompt: `"I'm working on 4.1 WebSocket server in ElysiaJS, guide me through it"`

- [ ] **4.2 Handle add_item and assign_item events server-side**
  - 🎯 *You'll learn:* event-driven architecture, save-then-broadcast pattern
  - 💬 Prompt: `"I'm working on 4.2 WebSocket event handlers, guide me through it"`

- [ ] **4.3 Connect Flutter to WebSocket and handle incoming events**
  - 🎯 *You'll learn:* web_socket_channel package, stream listeners, parsing JSON events
  - 💬 Prompt: `"I'm working on 4.3 Flutter WebSocket connection, guide me through it"`

- [ ] **4.4 Build Assign Menu screen (S10) — the real-time UI**
  - 🎯 *You'll learn:* optimistic updates, animated state changes, showing other users' avatars live
  - 💬 Prompt: `"I'm working on 4.4 Assign Menu screen UI, guide me through it"`

- [ ] **4.5 Handle reconnect + full state sync after disconnect**
  - 🎯 *You'll learn:* why mobile connections drop, exponential backoff, sync vs stream
  - 💬 Prompt: `"I'm working on 4.5 WebSocket reconnect and state sync, guide me through it"`

---

## Phase 5 — OCR (S07, S08)
*Can be done in parallel with Phase 4 by a different team member*

- [ ] **5.1 Integrate Google ML Kit OCR in Flutter**
  - 🎯 *You'll learn:* on-device ML, why on-device is better than cloud for this step
  - 💬 Prompt: `"I'm working on 5.1 ML Kit OCR integration, guide me through it"`

- [ ] **5.2 Build POST /bills/:id/ocr endpoint (LLM parsing)**
  - 🎯 *You'll learn:* prompt engineering for structured output, why you need LLM after OCR
  - 💬 Prompt: `"I'm working on 5.2 OCR endpoint with LLM, guide me through it"`

- [ ] **5.3 Build OCR Scanner and Review screens (S07, S08)**
  - 🎯 *You'll learn:* camera package, image cropping, editable list after parsing
  - 💬 Prompt: `"I'm working on 5.3 OCR Scanner and Review screens, guide me through it"`

---

## Phase 6 — Debt & Settle (S11–S15)

- [ ] **6.1 Write the debt simplification algorithm**
  - 🎯 *You'll learn:* the min-cash-flow problem, greedy algorithms, why naive splitting creates too many transfers
  - 💬 Prompt: `"I'm working on 6.1 Debt simplification algorithm, guide me through it"`

- [ ] **6.2 Build GET /bills/:id/debts endpoint**
  - 🎯 *You'll learn:* complex SQL joins, how to aggregate assign data into per-person totals
  - 💬 Prompt: `"I'm working on 6.2 Debts endpoint, guide me through it"`

- [ ] **6.3 Build Debt Summary and Bill Per Person screens (S13, S14)**
  - 🎯 *You'll learn:* TabBar, building per-person breakdown UI from nested data
  - 💬 Prompt: `"I'm working on 6.3 Debt Summary and Bill Per Person screens, guide me through it"`

- [ ] **6.4 Generate PromptPay QR server-side**
  - 🎯 *You'll learn:* EMVCo QR standard, CRC-16 checksum — how QR codes encode payment data
  - 💬 Prompt: `"I'm working on 6.4 PromptPay QR generation, guide me through it"`

- [ ] **6.5 Build PromptPay QR Payment screen (S15)**
  - 🎯 *You'll learn:* qr_flutter package, url_launcher for deep linking to banking apps, slip upload
  - 💬 Prompt: `"I'm working on 6.5 PromptPay QR screen, guide me through it"`

---

## Phase 7 — Polish

- [ ] **7.1 Bill Summary screens — App View + Receipt View (S11, S12)**
- [ ] **7.2 Profile & Settings screen (S16)**
- [ ] **7.3 Error handling audit** — every API call should have loading / error / empty state
- [ ] **7.4 Splash screen with auth redirect (S01)**
- [ ] **7.5 End-to-end test** — walk through all 6 user flows as a real user

---

## Progress Tracker

| Phase | Tasks | Done |
|-------|-------|------|
| 1 — Setup | 8 | 0 |
| 2 — Auth | 6 | 0 |
| 3 — Core Bill | 6 | 0 |
| 4 — Real-time ⭐ | 5 | 0 |
| 5 — OCR | 3 | 0 |
| 6 — Debt & Settle | 5 | 0 |
| 7 — Polish | 5 | 0 |
| **Total** | **38** | **0** |
