# BillGang — SplitBill

แอปพลิเคชัน Flutter สำหรับหารบิลอาหารและค่าใช้จ่ายร่วมกัน ออกแบบมาให้กลุ่มเพื่อนสามารถสร้างบิล เชิญสมาชิก และ Assign รายการอาหารของตัวเองได้แบบ Real-time โดยแอปจะคำนวณยอดที่แต่ละคนต้องจ่ายโดยอัตโนมัติ พร้อมสร้าง PromptPay QR Code สำหรับโอนเงินได้ทันที

## Key Features

- **Real-time Assign เมนู** — สมาชิกทุกคน assign รายการที่ตัวเองกินพร้อมกันได้ โดยเห็น avatar ของคนอื่นแบบ Live
- **OCR ใบเสร็จ** — ถ่ายรูปใบเสร็จแล้วให้ AI อ่านรายการอาหารและราคาให้อัตโนมัติผ่าน ML Kit + LLM
- **Debt Simplification Algorithm** — ลด transaction การโอนเงินให้น้อยที่สุด
- **PromptPay QR Generator** — สร้าง QR Code พร้อมจำนวนเงินที่ถูกต้อง สแกนได้จากทุกแอปธนาคารไทย
- **App View / Receipt View** — ดูบิลในรูปแบบ App UI หรือ toggle ดูใบเสร็จจริงที่ถ่ายไว้
- **บิลรายคน** — แสดงยอดรายบุคคลพร้อม breakdown ว่ากินอะไร แชร์กับใคร และหารกี่คน

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| State Management | Riverpod / BLoC |
| Database | Neon / PostgreSQL |
| Local Storage | SQLite (offline-first) |
| OCR | ML Kit + LLM |
| Payment | PromptPay QR |

## User Flow

```
1. Setup        → สมัครบัญชี, ตั้ง PromptPay, ตั้งชื่อ Profile
2. Create Bill  → สร้างบิล, เพิ่มเมนู / OCR, Invite เพื่อน
3. Assign       → Assign เมนู, Real-time sync, Shared item
4. Manage Debt  → ดูสรุปหนี้, Debt simplify, Breakdown
5. Settle Up    → PromptPay QR, Confirm จ่าย, Smart remind
```

## Getting Started

### Prerequisites

- Flutter SDK ^3.10.7
- Dart SDK
- Android Studio / VS Code

### Installation

```bash
# Clone the repository
git clone <repo-url>
cd cs356_billgang

# Install dependencies
flutter pub get

# Run the app
flutter run
```

## Team

| Name | Student ID |
|---|---|
| ธัญเทพ วิชัยดิษ | 1660702182 |
| สิทธินันท์ แดงมะแจ้ง | 1660702976 |
| ชยานันต์ ปทุมารักษ์ | 1660703537 |
| จีระเดช มักเจริญ | 1660703214 |
| อภิสิทธิ์ ด่านเจ้าแดง | 1660706803 |

**Advisor:** อาจารย์ ชนวีร์ พิพัฒน์กุล

**Course:** CS356 Mobile Application Development I — สาขาวิชาวิทยาการคอมพิวเตอร์ คณะเทคโนโลยีสารสนเทศและนวัตกรรม มหาวิทยาลัยกรุงเทพ ภาคเรียนที่ 2/2568
