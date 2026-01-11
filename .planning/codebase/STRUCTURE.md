# Codebase Structure

**Analysis Date:** 2026-01-11

## Directory Layout

```
sure/
├── app/
│   ├── models/
│   │   ├── provider/                 # AI provider implementations
│   │   │   ├── anthropic/            # Anthropic-specific code
│   │   │   │   ├── auto_categorizer.rb
│   │   │   │   ├── auto_merchant_detector.rb
│   │   │   │   └── chat_parser.rb
│   │   │   ├── openai/              # OpenAI-specific code
│   │   │   │   ├── auto_categorizer.rb
│   │   │   │   ├── auto_merchant_detector.rb
│   │   │   │   └── chat_parser.rb
│   │   │   ├── concerns/            # Shared provider concerns
│   │   │   │   └── usage_recorder.rb
│   │   │   ├── base.rb              # Base provider class
│   │   │   ├── registry.rb          # Provider registry
│   │   │   ├── factory.rb           # Provider factory
│   │   │   ├── llm_concept.rb       # AI capabilities interface
│   │   │   ├── anthropic.rb         # Anthropic provider
│   │   │   └── openai.rb            # OpenAI provider
│   │   ├── family/                  # Family-level operations
│   │   │   ├── auto_categorizer.rb  # Main categorization orchestrator
│   │   │   └── auto_merchant_detector.rb
│   │   ├── concerns/                # Model concerns
│   │   │   └── enrichable.rb        # Attribute enrichment with locking
│   │   ├── learned_pattern.rb       # Pattern learning storage
│   │   ├── learned_pattern_matcher.rb
│   │   ├── assistant.rb              # AI chat assistant
│   │   ├── message.rb               # Chat messages
│   │   ├── chat.rb                  # Chat sessions
│   │   ├── llm_usage.rb             # AI usage tracking
│   │   └── eval/                    # Evaluation framework
│   │       └── runners/
│   │           ├── categorization_runner.rb
│   │           └── merchant_detection_runner.rb
│   ├── controllers/
│   │   ├── transactions/
│   │   │   ├── ai_categorizations_controller.rb
│   │   │   └── bulk_ai_categorizations_controller.rb
│   │   ├── settings/
│   │   │   └── ai_prompts_controller.rb
│   │   ├── chats_controller.rb
│   │   └── api/v1/
│   │       └── chats_controller.rb
│   ├── jobs/
│   │   ├── auto_categorize_job.rb
│   │   ├── auto_detect_merchants_job.rb
│   │   └── assistant_response_job.rb
│   └── javascript/controllers/
│       ├── ai_categorize_controller.js
│       └── bulk_ai_categorize_controller.js
├── test/
│   ├── models/
│   │   ├── provider/
│   │   │   ├── anthropic_test.rb
│   │   │   └── openai_test.rb
│   │   ├── family/
│   │   │   └── auto_categorizer_test.rb
│   │   └── learned_pattern_test.rb
│   ├── controllers/
│   │   ├── transactions/
│   │   │   ├── ai_categorizations_controller_test.rb
│   │   │   └── bulk_ai_categorizations_controller_test.rb
│   │   └── settings/
│   │       └── ai_prompts_controller_test.rb
│   ├── system/
│   │   └── transactions_ai_categorize_system_test.rb
│   ├── vcr_cassettes/              # API response fixtures
│   │   ├── anthropic/
│   │   │   ├── auto_categorize.yml
│   │   │   └── auto_detect_merchants.yml
│   │   └── openai/
│   │       └── chat/
│   └── support/
│       ├── provider_test_helper.rb
│       └── entries_test_helper.rb
├── config/
│   ├── initializers/
│   └── locales/                    # i18n translations
├── db/
│   ├── schema.rb                   # Database schema
│   └── migrate/                    # Database migrations
├── docs/
│   └── hosting/
│       └── ai.md                   # AI configuration documentation
└── lib/
    └── tasks/                      # Rake tasks
```

## Directory Purposes

**app/models/provider/**
- Purpose: External AI/LLM service integrations
- Contains: Provider abstractions, Anthropic/OpenAI implementations
- Key files: `base.rb`, `anthropic.rb`, `openai.rb`, `llm_concept.rb`
- Subdirectories: `anthropic/`, `openai/`, `concerns/`

**app/models/family/**
- Purpose: Family-level business logic orchestration
- Contains: Auto-categorization, merchant detection
- Key files: `auto_categorizer.rb`, `auto_merchant_detector.rb`
- Subdirectories: None

**app/models/concerns/**
- Purpose: Shared model behaviors
- Contains: `enrichable.rb` for attribute enrichment
- Key files: `enrichable.rb`
- Subdirectories: None

**app/controllers/**
- Purpose: HTTP request handling
- Contains: AI categorization endpoints, chat endpoints
- Key files: `transactions/ai_categorizations_controller.rb`, `chats_controller.rb`
- Subdirectories: `transactions/`, `settings/`, `api/v1/`

**app/jobs/**
- Purpose: Background job processing
- Contains: Async AI operations
- Key files: `auto_categorize_job.rb`, `assistant_response_job.rb`
- Subdirectories: None

**app/javascript/controllers/**
- Purpose: Stimulus controllers for frontend interactivity
- Contains: AI categorization UI logic
- Key files: `ai_categorize_controller.js`, `bulk_ai_categorize_controller.js`
- Subdirectories: None

**test/**
- Purpose: Test suite
- Contains: Unit tests, integration tests, system tests
- Key files: VCR cassettes for API mocking
- Subdirectories: `models/`, `controllers/`, `system/`, `vcr_cassettes/`, `support/`

## Key File Locations

**Entry Points:**
- `app/controllers/transactions/ai_categorizations_controller.rb` - Individual categorization
- `app/controllers/transactions/bulk_ai_categorizations_controller.rb` - Bulk categorization
- `app/controllers/chats_controller.rb` - AI chat interface

**Configuration:**
- `config/credentials.yml.enc` - Encrypted credentials
- `.env.example` - Environment variable template
- `docs/hosting/ai.md` - AI configuration guide

**Core Logic (AI):**
- `app/models/provider/anthropic.rb` - Anthropic provider
- `app/models/provider/openai.rb` - OpenAI provider
- `app/models/family/auto_categorizer.rb` - Categorization orchestrator
- `app/models/provider/anthropic/auto_categorizer.rb` - Anthropic categorization logic
- `app/models/provider/openai/auto_categorizer.rb` - OpenAI categorization logic

**Core Logic (Learning):**
- `app/models/learned_pattern.rb` - Pattern storage
- `app/models/learned_pattern_matcher.rb` - Pattern matching

**Testing:**
- `test/models/provider/anthropic_test.rb` - Anthropic provider tests
- `test/models/family/auto_categorizer_test.rb` - Categorizer tests
- `test/support/provider_test_helper.rb` - Test helpers
- `test/vcr_cassettes/` - API response fixtures

**Documentation:**
- `docs/hosting/ai.md` - Comprehensive AI configuration guide
- `CLAUDE.md` - Project-specific guidance for Claude Code

## Naming Conventions

**Files:**
- snake_case.rb for Ruby files
- {feature}_controller.rb for controllers
- {feature}_job.rb for background jobs
- {provider}_{feature}.rb for provider-specific implementations
- *_test.rb for test files

**Classes/Modules:**
- PascalCase for classes and modules
- `Provider::{ProviderName}` for provider classes
- `Provider::{ProviderName}::{FeatureName}` for provider features
- `{Model}::{Feature}` for namespaced model features

**Methods:**
- snake_case for method names
- `auto_{action}` for AI operations (e.g., `auto_categorize`)
- `{verb}_{noun}?` for predicate methods (e.g., `custom_provider?`)

**Special Patterns:**
- `Error = Class.new(Provider::Error)` for provider-specific errors
- `*_controller.rb` for Stimulus controllers
- `*_test.rb` for test files (co-located with source or in test/)

## Where to Add New Code

**New Provider:**
- Implementation: `app/models/provider/{provider_name}.rb`
- Features: `app/models/provider/{provider_name}/`
- Tests: `test/models/provider/{provider_name}_test.rb`

**New AI Feature:**
- Provider interface: `app/models/provider/base.rb` (add method)
- Provider implementations: `app/models/provider/{provider}/*.rb`
- Orchestrator: `app/models/family/`
- Controller: `app/controllers/`
- Tests: `test/models/`, `test/controllers/`

**New Background Job:**
- Implementation: `app/jobs/{feature}_job.rb`
- Tests: `test/jobs/{feature}_job_test.rb`

**New Stimulus Controller:**
- Implementation: `app/javascript/controllers/{name}_controller.js`

## Special Directories

**test/vcr_cassettes/**
- Purpose: Recorded HTTP interactions for API testing
- Source: VCR gem during test runs
- Committed: Yes (gitignored sensitive data via filters)

**app/models/concerns/**
- Purpose: Shared model behaviors via Rails concerns
- Source: Hand-written modules
- Committed: Yes

**app/models/eval/**
- Purpose: AI evaluation and benchmarking framework
- Source: Hand-written evaluation code
- Committed: Yes

---

*Structure analysis: 2026-01-11*
*Update when directory structure changes*
