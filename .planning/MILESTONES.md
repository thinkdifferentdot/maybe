# Project Milestones: Anthropic Support for Sure

## v1.2 Anthropic Feature Parity (Shipped: 2026-01-11)

**Delivered:** Achieved feature parity between OpenAI and Anthropic provider implementations with real streaming support, fuzzy category/merchant matching, and centralized usage recording.

**Phases completed:** 16-18, 20 (4 plans total)

**Key accomplishments:**

- Implemented token-by-token streaming for Anthropic chat using MessageStream API with ChatStreamParser
- Added auto_categorize test coverage matching OpenAI implementation patterns
- Ported fuzzy name matching from OpenAI for better category/merchant normalization
- Extracted ~160 lines of duplicate code into shared Provider::Concerns::UsageRecorder module

**Stats:**

- 29 files created/modified
- +3,855 net lines of code (+4,086 added, -231 removed)
- 4 phases, 4 plans
- ~1 day from v1.1 to ship (2026-01-10 → 2026-01-11)

**Git range:** `feat(16-01)` → `test(20-01)`

**What's next:** v1.3 Codebase Health — reduce technical debt, extract JSON parser, improve categorization prompts

---

## v1.1 AI Auto-Categorization Triggers (Shipped: 2026-01-10)

**Delivered:** Complete AI auto-categorization workflow with settings UI, import/sync triggers, individual/bulk categorize actions, and comprehensive test coverage.

**Phases completed:** 10-15 + 14.1 + 14.2 (8 plans total)

**Key accomplishments:**

- Added AI trigger settings to Setting model (ai_categorize_on_import, ai_categorize_on_sync, ai_categorize_on_ui_action)
- Created LearnedPattern model for AI categorization pattern learning
- Implemented AI categorization triggers in CSV import and Lunchflow sync jobs
- Built individual and bulk AI categorization workflows with confidence tracking
- Added 50+ tests for LearnedPattern model, controllers, and system integration

**Stats:**

- 40+ files created/modified
- 8 phases, 8 plans
- ~1 day from v1.0 to ship (2026-01-09 → 2026-01-10)

**Git range:** `feat(10-01)` → `feat(15-01)`

---

## v1.0 Anthropic Support (Shipped: 2026-01-10)

**Delivered:** Full Anthropic Claude integration as a first-class LLM provider alongside OpenAI with settings UI, registry integration, and observability.

**Phases completed:** 1-9 + 9.1 (26 plans total)

**Key accomplishments:**

- Created Provider::Anthropic class with auto_categorize, auto_detect_merchants, chat_response methods
- Registered Anthropic in provider registry with cost tracking for all Claude models
- Built settings UI with provider selector dropdown and Anthropic configuration form
- Implemented Langfuse tracing for all Anthropic operations
- Fixed compatibility issues (symbol keys, function_results format, provider switching)

**Stats:**

- 62 files created/modified
- +6,372 lines of code
- 10 phases, 26 plans
- ~1 day development time (2026-01-09 → 2026-01-10)

**Git range:** `feat(1-01)` → `fix(9.1-01)`

---

*Last updated: 2026-01-11*
