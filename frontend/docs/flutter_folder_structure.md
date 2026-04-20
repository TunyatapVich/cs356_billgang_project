# Flutter Folder Structure — Feature-First Architecture

นี่คือ structure ที่ scalable ที่สุดสำหรับ production Flutter app:

```
lib/
├── core/                          # Shared, app-wide utilities
│   ├── constants/
│   │   ├── app_colors.dart
│   │   ├── app_strings.dart
│   │   └── app_sizes.dart
│   ├── errors/
│   │   ├── exceptions.dart        # Custom exceptions
│   │   └── failures.dart          # Domain failures (Either type)
│   ├── network/
│   │   ├── dio_client.dart        # HTTP client setup (interceptors, base URL)
│   │   └── api_endpoints.dart
│   ├── utils/
│   │   └── date_formatter.dart
│   └── widgets/                   # Truly shared UI components
│       ├── app_button.dart
│       └── loading_overlay.dart
│
├── features/                      # Feature-first grouping ← หัวใจหลัก
│   └── auth/
│       ├── data/
│       │   ├── datasources/
│       │   │   └── auth_remote_datasource.dart   # API calls
│       │   ├── models/
│       │   │   └── user_model.dart               # JSON serialization
│       │   └── repositories/
│       │       └── auth_repository_impl.dart
│       │
│       ├── domain/
│       │   ├── entities/
│       │   │   └── user.dart                     # Pure Dart class, no Flutter dep
│       │   ├── repositories/
│       │   │   └── auth_repository.dart          # Abstract interface
│       │   └── usecases/
│       │       └── login_usecase.dart
│       │
│       └── presentation/
│           ├── bloc/                             # หรือ provider/ / notifier/
│           │   ├── auth_bloc.dart
│           │   ├── auth_event.dart
│           │   └── auth_state.dart
│           ├── pages/
│           │   └── login_page.dart
│           └── widgets/                          # Widget เฉพาะ feature นี้
│               └── login_form.dart
│
└── main.dart
```

## แต่ละ Layer ทำอะไร?

### `data/` → รู้เรื่อง API, JSON, Database

- **datasources** — เรียก HTTP, local DB
- **models** — มี `fromJson`/`toJson`
- **repositories/impl** — combine datasources, handle errors

### `domain/` → Pure business logic, ไม่มี Flutter/HTTP dependency

- **entities** — plain Dart object
- **repositories** — abstract interface (dependency inversion)
- **usecases** — 1 usecase = 1 business action

### `presentation/` → ทุกอย่างที่ user เห็นและ state ของมัน

- **bloc/** (หรือ notifier/, provider/) — state management
- **pages/** — screen-level widget
- **widgets/** — component เฉพาะ feature

## เลือก State Management ให้เหมาะกับขนาด App

| ขนาด | แนะนำ |
|---|---|
| เล็ก / prototype | `setState` + `Provider` |
| กลาง | `Riverpod` (Notifier) |
| ใหญ่ / team | `Bloc` + Clean Architecture |

## ข้อควรจำ

- **อย่า** ให้ Widget เรียก API โดยตรง — ผ่าน state layer เสมอ
- **อย่า** ให้ `data/models` ไปอยู่ใน `domain/` — เพราะ model มี JSON logic แต่ entity ต้องบริสุทธิ์
- `core/` คือของที่ใช้ได้ทุก feature — ถ้ามันเฉพาะ feature เดียว ให้อยู่ใน feature นั้นเลย
