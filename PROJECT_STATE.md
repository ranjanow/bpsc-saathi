# PROJECT_STATE.md — BPSC/UPSC Examination Intelligence System

> **Purpose**: Cross-model state tracking file. Any AI agent (GPT, Claude, Gemini, etc.) resuming work on this project MUST read this file first.

---

## 1. System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    MONOREPO ROOT                        │
│                   /bpsc-engine                          │
├─────────────────────┬───────────────────────────────────┤
│     /backend (Go)   │      /frontend (Flutter/Dart)     │
│                     │                                   │
│  main.go            │  lib/                             │
│  /models            │    main.dart                      │
│    ecosystem.go     │    /models                        │
│    profile.go       │      ecosystem_model.dart         │
│  /handlers          │      syllabus_model.dart          │
│    health.go        │    /screens                       │
│    ecosystem.go     │      dashboard_screen.dart        │
│    daily_quiz.go    │      syllabus_screen.dart         │
│    syllabus.go      │      prelims_arena_screen.dart    │
│    profile.go       │      mains_writing_screen.dart    │
│    middleware.go    │      daily_quiz_screen.dart       │
│                     │      stub_screens.dart (Profile)  │
│  Port: 8080         │    /services                      │
│  DB: PostgreSQL     │      api_service.dart             │
│                     │    /widgets                       │
│                     │      widgets.dart (barrel)        │
│                     │                                   │
│                     │  Targets: Web + Mobile (iOS/And)  │
└─────────────────────┴───────────────────────────────────┘
```

### Data Flow
```
Flutter App  ──HTTP──▶  Go API Server (8080)  ──SQL──▶  PostgreSQL
                           │
                     /ping (health)
                     /api/v1/generate-ecosystem
                     /api/v1/daily-quiz
                     /api/v1/syllabus
                     /api/v1/profile
                     /api/v1/profile/stats
                     /api/v1/tutor
                     /api/v1/syllabus-refresher
                     /api/v1/mains-evaluate
                     /api/v1/bookmarks
```

### Core Domain Model: `EcosystemResponse`
```json
{
  "coreTopic": "string",
  "connectedStaticConcepts": ["string"],
  "generatedQuestions": [
    {
      "id": "string",
      "question_en": "string",
      "question_hi": "string",
      "options_en": ["string"],
      "options_hi": ["string"],
      "correctOptionIndex": 0,
      "explanation_en": "string",
      "explanation_hi": "string",
      "difficulty": "easy | medium | hard",
      "subject": "string",
      "pyqYear": "string — e.g. 'BPSC 67th 2022' or '' if original"
    }
  ]
}
```

---

## 2. Tech Stack

| Layer      | Technology          | Version   | Notes                          |
|------------|---------------------|-----------|--------------------------------|
| Backend    | Go                  | 1.22+     | net/http, encoding/json        |
| Frontend   | Flutter / Dart      | 3.x       | Provider, Material 3           |
| Database   | PostgreSQL          | 15+       | Connection pool wired (lib/pq) |
| LLM        | Google Gemini 1.5 Flash | latest | generative-ai-go/genai SDK |
| State Mgmt | Provider            | 6.1.2     | Can migrate to Riverpod        |

---

## 3. Task Checklist

### Phase 1: Monorepo Scaffold

| #  | Task                                        | Status         |
|----|---------------------------------------------|----------------|
| 1  | Create PROJECT_STATE.md                     | ✅ Complete    |
| 2  | Backend: `go mod init bpsc-engine`          | ✅ Complete    |
| 3  | Backend: `/models/ecosystem.go` structs     | ✅ Complete    |
| 4  | Backend: `/handlers/health.go` (`/ping`)    | ✅ Complete    |
| 5  | Backend: `/handlers/ecosystem.go` endpoint  | ✅ Complete    |
| 6  | Backend: CORS middleware + Logging MW       | ✅ Complete    |
| 7  | Backend: `main.go` HTTP server on :8080     | ✅ Complete    |
| 8  | Frontend: `lib/` directory structure        | ✅ Complete    |
| 9  | Frontend: `main.dart` Material 3 shell      | ✅ Complete    |
| 10 | Frontend: `ecosystem_model.dart`            | ✅ Complete    |
| 11 | Frontend: `api_service.dart`                | ✅ Complete    |
| 12 | Frontend: Screen stubs (3 tabs)             | ✅ Complete    |

### Phase 2: Database & ORM
| #  | Task                                                         | Status         |
|----|--------------------------------------------------------------|----------------|
| 13 | PostgreSQL schema migration (`001_initial_schema.sql`)       | ✅ Complete    |
| 14 | Go DB connection pool (`database/sql`+`pq`)                  | ✅ Complete    |
| 15 | CRUD repository layer (`repositories/ecosystem_repo.go`)     | ✅ Complete    |

### Phase 3: LLM Integration + API Wiring
| #  | Task                                                                   | Status         |
|----|------------------------------------------------------------------------|----------------|
| 16 | Choose LLM provider (Google Gemini API recommended)                    | ✅ Complete    |
| 17 | Create `backend/services/llm_service.go` — prompt builder + API call   | ✅ Complete    |
| 18 | Update `handlers/ecosystem.go` to call LLM service + repo.SaveEcosystem| ✅ Complete    |
| 19 | Store `GEMINI_API_KEY` (or provider key) in `.env` / env var           | ✅ Complete    |
| 20 | Wire Flutter → Go `/ping` (verify connectivity)                        | ✅ Complete    |
| 21 | Wire Flutter → Go `/api/v1/generate-ecosystem` (full round-trip)       | ✅ Complete    |
| 22 | Flutter: loading states, error banners, result rendering               | ✅ Complete    |

---

## 4. Current Status

- **Last Updated**: 2026-06-19T10:45:00+05:30
- **Last Agent**: Antigravity (Claude Opus 4)
- **Current Phase**: Phase 7 — Navigation Restructuring Complete ✅
- **Backend Version**: 0.5.0 (Phase 6: Navigation Restructure)
- **Blocking Issues**: None
- **Changes Made (Phase 7)**:
  - Restructured sidebar: HOME → SYLLABUS → PRELIMS → MAINS → DAILY QUIZ → PROFILE
  - Removed Progress and Community screens (frontend + backend)
  - Cleaned dashboard: removed Gateway Cards, Radar Chart, Syllabus Explorer, Bookmarks
  - Created dedicated Syllabus screen with complete BPSC Prelims + Mains syllabus
  - Expanded `syllabus_model.dart` with 8 subjects × full topic trees
  - Created `backend/handlers/syllabus.go` — GET /api/v1/syllabus
  - Created Daily Quiz feature: 15 PYQ-only questions, bilingual (Hindi+English)
  - Created `backend/handlers/daily_quiz.go` — POST /api/v1/daily-quiz
  - Added `GenerateDailyQuiz()` to LLM service with dedicated professor persona prompt
  - Created Profile backend: GET/PUT /api/v1/profile, GET /api/v1/profile/stats
  - Built full ProfileScreen with stats, editable fields, language preference
  - Updated `api_service.dart` with getDailyQuiz(), getSyllabus(), getProfile(), updateProfile()
  - Fixed `weakness_radar_chart.dart` — moved `RadarDataPoint` type inline
  - 0 compile errors (flutter analyze + go build clean)
- **Next Action**: Feature expansion
  - Wire profile stats to real quiz completion data
  - Add daily quiz caching (avoid re-generation on same day)
  - Add theme switcher to mobile (currently desktop-only)

---

## 5. File Registry

> Every file created/modified must be logged here.

| File Path                                                | Status   | Last Modified By |
|----------------------------------------------------------|----------|------------------|
| `PROJECT_STATE.md`                                       | Updated  | Antigravity      |
| `backend/go.mod`                                         | Updated  | Antigravity      |
| `backend/go.sum`                                         | Updated  | Antigravity      |
| `backend/main.go`                                        | Updated  | Antigravity      |
| `backend/database.go`                                    | Created  | Antigravity      |
| `backend/migrations/001_initial_schema.sql`              | Created  | Antigravity      |
| `backend/repositories/ecosystem_repo.go`                 | Bugfix   | Antigravity      |
| `backend/services/llm_service.go`                        | Created  | Antigravity      |
| `backend/handlers/ecosystem.go`                          | Updated  | Antigravity      |
| `backend/models/ecosystem.go`                            | Created  | Antigravity      |
| `backend/handlers/health.go`                             | Created  | Antigravity      |
| `backend/handlers/middleware.go`                         | Created  | Antigravity      |
| `frontend/pubspec.yaml`                                  | Created  | Antigravity      |
| `frontend/design/bpsc_saathi_dashboard.html`             | Created  | Antigravity      |
| `frontend/lib/main.dart`                                 | Rewrite  | Antigravity      |
| `frontend/lib/theme/app_theme.dart`                      | Rewrite  | Antigravity      |
| `frontend/lib/theme/theme_provider.dart`                 | Created  | Antigravity      |
| `frontend/lib/screens/dashboard_screen.dart`             | Rewrite  | Antigravity      |
| `frontend/lib/screens/stub_screens.dart`                 | Created  | Antigravity      |
| `frontend/lib/screens/prelims_arena_screen.dart`         | Existing | Antigravity      |
| `frontend/lib/screens/mains_simulator_screen.dart`       | Existing | Antigravity      |
| `frontend/lib/screens/mains_writing_screen.dart`         | Existing | Antigravity      |
| `frontend/lib/widgets/widgets.dart`                      | Updated  | Antigravity      |
| `frontend/lib/widgets/diya_icon.dart`                    | Created  | Antigravity      |
| `frontend/lib/widgets/app_sidebar.dart`                  | Created  | Antigravity      |
| `frontend/lib/widgets/hero_quiz_banner.dart`             | Created  | Antigravity      |
| `frontend/lib/widgets/subject_tile_widget.dart`          | Created  | Antigravity      |
| `frontend/lib/widgets/countdown_ring_widget.dart`        | Created  | Antigravity      |
| `frontend/lib/widgets/leaderboard_widget.dart`           | Created  | Antigravity      |
| `frontend/lib/widgets/daily_stats_widget.dart`           | Existing | Antigravity      |
| `frontend/lib/widgets/weakness_radar_chart.dart`         | Updated  | Antigravity      |
| `frontend/lib/widgets/syllabus_tree_widget.dart`         | Existing | Antigravity      |
| `frontend/lib/models/ecosystem_model.dart`               | Existing | Antigravity      |
| `frontend/lib/models/syllabus_model.dart`                | Rewrite  | Antigravity      |
| `frontend/lib/screens/syllabus_screen.dart`              | Created  | Antigravity      |
| `frontend/lib/screens/daily_quiz_screen.dart`            | Created  | Antigravity      |
| `frontend/lib/services/api_service.dart`                 | Updated  | Antigravity      |
| `frontend/test/widget_test.dart`                         | Updated  | Antigravity      |
| `backend/handlers/daily_quiz.go`                         | Created  | Antigravity      |
| `backend/handlers/syllabus.go`                           | Created  | Antigravity      |
| `backend/handlers/profile.go`                            | Created  | Antigravity      |
| `backend/models/profile.go`                              | Created  | Antigravity      |
| `backend/services/llm_service.go`                        | Updated  | Antigravity      |

---

## 6. Important Conventions

- **API Prefix**: All API routes use `/api/v1/` prefix.
- **JSON Naming**: `camelCase` in JSON, `PascalCase` in Go structs, `snake_case` in Dart fields internally.
- **Error Response**: `{ "error": "message", "code": 400 }`
- **Port**: Backend always runs on `:8080`.
- **CORS**: Allows `localhost:*` origins for local Flutter dev.
- **Navigation (Sidebar)**: HOME → SYLLABUS → PRELIMS → MAINS → DAILY QUIZ → PROFILE
- **Navigation (Mobile)**: HOME → PRELIMS → DAILY QUIZ → MAINS → PROFILE (5-item bottom bar)
- **Theming**: 3 themes (Vibrant, Professional, Dark Tech) via `BpscThemeData` InheritedWidget
- **Daily Quiz**: 15 PYQ-only questions, bilingual (Hindi+English), one per day

---

## 7. How to Run

### Backend (Go)
```bash
cd backend
# Required: Gemini API key (get one free at https://aistudio.google.com/app/apikey)
$env:GEMINI_API_KEY="your-gemini-key-here"     # PowerShell
# export GEMINI_API_KEY="your-gemini-key-here" # bash/zsh

# Optional: real DB password
$env:BPSC_DB_PASSWORD="your_actual_password"   # PowerShell

go run .
# Server starts on http://localhost:8080

# Test health:
# curl http://localhost:8080/ping

# Test AI generation (PowerShell):
# Invoke-RestMethod -Method POST -Uri http://localhost:8080/api/v1/generate-ecosystem \
#   -ContentType "application/json" \
#   -Body '{"topic":"Revolt of 1857","limit":3,"difficulty":"medium"}'
```

### Frontend (Flutter)
```bash
cd frontend
flutter pub get
flutter run -d chrome    # Web
flutter run              # Mobile (connected device/emulator)
```

---

## 8. Schema Contract

The Go and Dart models are kept in strict sync:
- **Go**: `backend/models/ecosystem.go`
- **Dart**: `frontend/lib/models/ecosystem_model.dart`

⚠️ **Any change to one MUST be mirrored in the other.** The JSON field names are the contract boundary.
