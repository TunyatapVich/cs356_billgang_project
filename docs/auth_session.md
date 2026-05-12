# Auth System — Session Persistence

## Overview

ระบบ authentication ของ app ใช้ JWT token ที่เก็บใน `FlutterSecureStorage` (encrypted storage บน device) และ restore session อัตโนมัติเมื่อเปิด app ขึ้นมา

## Flow

```
App Launch
    │
    ▼
AuthNotifier.build()
    │
    ├─── TokenStorage.read() ──── null ──► ไป login screen
    │                    │
    │                    └─── has token ──► getProfile() API
    │                                          │
    │                              OK ──► ไป home screen (logged in)
    │                              ERR ──► ไป login screen (token หมดอายุ)
    │
    ▼
User ทำ login/register
    │
    ▼
AuthService.login() / register()
    │
    ▼
Backend ตอบกลับ { token, user }
    │
    ▼
TokenStorage.save(token)
    │
    ▼
state = AsyncData(User)  ──► UI update ไป home
```

## Key Files

| File | Role |
|------|------|
| `auth_provider.dart` | `AuthNotifier` — เก็บ `User?` state, เรียก API ผ่าน service |
| `auth_service.dart` | ทำ HTTP calls: `/login`, `/register`, `/profile`, `/profile` (PUT) |
| `token_storage.dart` | wrapper รอบ `FlutterSecureStorage` — save/read/delete JWT |

## Session Lifetime

- Token จาก backend มี expiry — ถ้าหมดแล้ว `getProfile()` จะ fail → ไป login
- ทุกครั้งที่ app launch, `build()` จะ validate token กับ backend ก่อน restore session (ไม่ trust token เฉยๆ)
- `logout()` ลบ token ออก → state = `null` → ไป login screen