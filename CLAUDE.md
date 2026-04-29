# CLAUDE.md — BillGang Project Guide

## Frontend: Flutter + Riverpod

### Folder Structure

```
frontend/lib/
├── main.dart
├── app.dart                          # MaterialApp + ProviderScope bootstrap
│
├── core/                             # Shared across all features
│   ├── api/
│   │   └── api_client.dart           # Dio instance + JWT interceptor
│   ├── router/
│   │   └── app_router.dart           # go_router routes + auth redirect guard
│   ├── socket/
│   │   └── socket_client.dart        # WebSocket manager (connect/reconnect/resync)
│   └── storage/
│       └── token_storage.dart        # flutter_secure_storage wrapper
│
└── features/
    ├── auth/
    │   ├── auth_service.dart          # API calls: POST /register, /login, PUT /profile
    │   ├── auth_provider.dart         # AsyncNotifier: holds User + token state
    │   ├── login_screen.dart
    │   ├── register_screen.dart
    │   ├── profile_setup_screen.dart
    │   └── widgets/
    │
    ├── bill/
    │   ├── bill_service.dart          # API calls: CRUD bills + items
    │   ├── bill_provider.dart         # AsyncNotifier: bill list state
    │   ├── create_bill_screen.dart
    │   ├── add_items_screen.dart      # optimistic updates live here
    │   ├── ocr_review_screen.dart     # edit items parsed from OCR
    │   └── widgets/
    │
    ├── invite/
    │   ├── invite_service.dart        # POST /bills/:id/invite, POST /bills/join/:code
    │   ├── invite_screen.dart         # show QR Code + copy link
    │   └── join_screen.dart           # scan QR / deep link entry point
    │
    ├── assign/
    │   ├── assign_provider.dart       # StateNotifier: real-time WS bill room state
    │   ├── assign_screen.dart         # live assign UI
    │   └── widgets/
    │       └── item_card.dart         # item row with assigned member avatars
    │
    └── settlement/
        ├── settlement_service.dart    # GET /bills/:id/debts, POST /payments
        ├── settlement_screen.dart     # debt summary + who owes who
        ├── promptpay_screen.dart      # PromptPay QR + confirm slip
        └── widgets/
```

### Mental Model (React → Flutter)

| Flutter                    | React/Next.js equivalent                  |
| -------------------------- | ----------------------------------------- |
| `*_service.dart`           | `lib/api/auth.ts` (fetch/axios functions) |
| `*_provider.dart`          | `useAuth()` hook / Zustand store          |
| `*_screen.dart`            | `app/login/page.tsx`                      |
| `widgets/`                 | `components/`                             |
| `core/socket/`             | socket.io client wrapper                  |
| `core/api/api_client.dart` | axios instance with interceptors          |

### State Management: Riverpod

- Use `AsyncNotifier` for anything async (API calls, auth state)
- Use `Notifier` for sync state (UI toggles, local form state)
- Use `StreamNotifier` for WebSocket streams (assign feature)
- Provider files live inside their feature folder, not in a global `providers/` folder

### Key Conventions

- **Screens never call API directly** — always go through `*_service.dart` → provider
- **`core/` is for truly shared things** — if it's only used by one feature, put it inside that feature
- **Optimistic updates** — update provider state immediately, revert on API error (bill/assign features)
- **WebSocket state** — `socket_client.dart` handles low-level connect/reconnect; `assign_provider.dart` subscribes to its stream and exposes typed state to UI

### Flutter Packages

| Package                         | Purpose                      |
| ------------------------------- | ---------------------------- |
| `flutter_riverpod`              | State management             |
| `dio`                           | HTTP client                  |
| `go_router`                     | Navigation + auth guard      |
| `flutter_secure_storage`        | JWT token persistence        |
| `web_socket_channel`            | WebSocket (assign real-time) |
| `google_mlkit_text_recognition` | On-device OCR                |
| `qr_flutter`                    | Generate PromptPay QR        |

---

## Backend: ElysiaJS + Prisma

Located in `backend/src/modules/`. Each module has:

- `index.ts` — Elysia route definitions
- `model.ts` — request/response type schemas
- `service.ts` — business logic + DB calls

Current modules: `auth`

---

## Docs

Flow diagrams in `/docs/*.mermaid`:

- `01_auth_flow` — register, Google Sign-In, profile setup
- `02_create_bill_flow` — create bill, add items, optimistic updates
- `03_ocr_flow` — ML Kit → LLM → review screen
- `04_invite_join_flow` — QR code invite, deep link join
- `05_realtime_assign_flow` — WebSocket room, live assign, reconnect/resync
- `06_debt_settle_flow` — debt calculation, PromptPay QR, confirm payment
