# BillGang — SplitBill

แอปพลิเคชัน Flutter สำหรับหารบิลอาหารและค่าใช้จ่ายร่วมกัน กลุ่มเพื่อนสร้างบิล เชิญสมาชิก และ Assign รายการอาหารแบบ Real-time โดยแอปคำนวณยอดที่แต่ละคนต้องจ่ายอัตโนมัติพร้อมสร้าง PromptPay QR Code

## Features

- **Real-time Assign** — สมาชิก assign รายการพร้อมกันได้ เห็น avatar ของคนอื่นแบบ Live ผ่าน WebSocket
- **OCR ใบเสร็จ** — ถ่ายรูปใบเสร็จแล้วให้ ML Kit + LLM อ่านรายการและราคาให้อัตโนมัติ
- **Debt Simplification** — ลด transaction การโอนเงินให้น้อยที่สุดด้วย min-cash-flow algorithm
- **PromptPay QR** — สร้าง QR Code พร้อมจำนวนเงิน สแกนได้จากทุกแอปธนาคารไทย
- **Invite via QR / Deep Link** — เชิญเพื่อนเข้าบิลผ่าน QR Code หรือ Link

## Tech Stack

| Layer            | Technology                       |
| ---------------- | -------------------------------- |
| Frontend         | Flutter (Dart)                   |
| State Management | Riverpod (AsyncNotifier)         |
| Backend          | ElysiaJS (Bun)                   |
| Database         | Neon / PostgreSQL (Prisma)       |
| Real-time        | WebSocket (`web_socket_channel`) |
| OCR              | ML Kit (on-device) + LLM API     |
| Routing          | go_router                        |
| HTTP             | Dio                              |
| Auth             | JWT + flutter_secure_storage     |
| Storage          | Cloudinary (Unsigned Preset)     |

## User Flow

```
1. Auth         → Register / Login → Setup Profile (display_name, PromptPay)
2. Create Bill  → สร้างบิล → เพิ่มเมนูมือ / OCR ใบเสร็จ
3. Invite       → แชร์ QR Code / Link ให้เพื่อน
4. Assign       → Real-time assign เมนู ดู avatar คนอื่น Live
5. Settle Up    → ดูสรุปหนี้ → PromptPay QR → Confirm จ่าย
```

## Getting Started

### Prerequisites

- Flutter SDK `^3.10.7`
- Bun (backend runtime)
- PostgreSQL (or Neon account)

### Run Frontend

```bash
cd frontend
flutter pub get
flutter run
```

### Run Backend

```bash
cd backend
bun install
bun run dev
```

## Project Structure

```
cs356_billgang/
├── frontend/          # Flutter app
│   └── lib/
│       ├── core/      # Shared: API client, router, socket, storage
│       └── features/  # auth | bill | invite | assign | settlement
├── backend/           # ElysiaJS API
│   └── src/
│       └── modules/   # auth | bills | ws | payments
└── docs/              # Flow diagrams (.mermaid)
```

See `CLAUDE.md` for detailed frontend folder structure and conventions.

## Team

| Name                  | Student ID |
| --------------------- | ---------- |
| ธัญเทพ วิชัยดิษ       | 1660702182 |
| สิทธินันท์ แดงมะแจ้ง  | 1660702976 |
| ชยานันต์ ปทุมารักษ์   | 1660703537 |
| จีระเดช มักเจริญ      | 1660703214 |
| อภิสิทธิ์ ด่านเจ้าแดง | 1660706803 |

**Advisor:** อาจารย์ ชนวีร์ พิพัฒน์กุล

**Course:** CS356 Mobile Application Development I — สาขาวิชาวิทยาการคอมพิวเตอร์ คณะเทคโนโลยีสารสนเทศและนวัตกรรม มหาวิทยาลัยกรุงเทพ ภาคเรียนที่ 2/2568
