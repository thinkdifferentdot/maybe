# Architecture

**Analysis Date:** 2026-01-11

## Pattern Overview

**Overall:** Modular Monolith with Provider Abstraction Pattern

**Key Characteristics:**
- Single Rails application with clear module boundaries
- Provider pattern for external service abstraction
- Background job processing for async operations
- Hotwire for reactive UI without heavy JavaScript

## Layers

**Provider Layer:**
- Purpose: Abstract external AI/LLM service integrations
- Contains: `Provider::Base`, `Provider::Anthropic`, `Provider::Openai`, `Provider::Registry`
- Location: `app/models/provider/`
- Depends on: External AI APIs (Anthropic, OpenAI), Langfuse
- Used by: Application layer for AI operations

**Application Layer:**
- Purpose: Business logic orchestration
- Contains: `Family::AutoCategorizer`, `Family::AutoMerchantDetector`, `LearnedPattern`
- Location: `app/models/family/`, `app/models/`
- Depends on: Provider layer, database models
- Used by: Controllers and background jobs

**Data Layer:**
- Purpose: Persistent storage and retrieval
- Contains: ActiveRecord models (Transaction, Category, Merchant, LlmUsage)
- Location: `app/models/`
- Depends on: PostgreSQL database
- Used by: All layers above

**Learning Layer:**
- Purpose: Rule-based categorization fallback
- Contains: `LearnedPattern`, `LearnedPatternMatcher`
- Location: `app/models/`
- Depends on: Transaction history
- Used by: Auto-categorizer before AI attempts

**Evaluation Layer:**
- Purpose: Test and measure AI performance
- Contains: `Eval::Runners::CategorizationRunner`, `Eval::Runners::MerchantDetectionRunner`
- Location: `app/models/eval/runners/`
- Depends on: Provider layer, test data
- Used by: Evaluation scripts and Rake tasks

## Data Flow

**Transaction Auto-Categorization Flow:**

1. User triggers AI categorization via UI (button click or bulk action)
   - Entry point: `Transactions::AiCategorizationsController#create`
   - Bulk: `Transactions::BulkAiCategorizationsController#create`

2. Controller orchestrates categorization
   - Filters for uncategorized, enrichable transactions
   - Instantiates `Family::AutoCategorizer` with transaction IDs

3. AutoCategorizer attempts rule-based matching first
   - Applies `LearnedPatternMatcher` for fast pattern matches
   - Only sends unmatched transactions to AI

4. Provider selection via `Provider::Registry`
   - Checks for configured LLM provider (OpenAI or Anthropic)
   - Falls back to learned patterns if no provider configured

5. Provider-specific AutoCategorizer processes
   - Formats transactions and user categories as LLM prompt
   - Calls AI API with structured JSON output request
   - Parses response with flexible JSON parsing (handles multiple formats)
   - Returns results with confidence scores

6. Transaction enrichment via `Enrichable` concern
   - Updates transaction with category_id
   - Stores AI metadata (confidence score, model used)
   - Locks attributes to prevent override

7. UI updates via Turbo Streams
   - Replaces category dropdowns with new selections
   - Shows summary modal with results

**AI Chat Flow:**

1. User sends message via chat UI
2. `ChatsController` creates message and queues `AssistantResponseJob`
3. Job processes via `Assistant` model with provider
4. Provider calls LLM with function/tool calling capabilities
5. Response streamed back via `ChatStreamParser`
6. UI updates in real-time

**State Management:**
- Server-side state (Rails sessions)
- No persistent in-memory state between requests
- Background jobs for long-running operations

## Key Abstractions

**Provider:**
- Purpose: Abstract external service integrations
- Examples: `Provider::Anthropic`, `Provider::Openai`
- Pattern: Base class with shared concerns, subclass for specific implementations
- Key methods: `chat_response`, `auto_categorize`, `auto_detect_merchants`

**LlmConcept:**
- Purpose: Define AI capabilities interface
- Location: `app/models/provider/llm_concept.rb`
- Pattern: Module included by provider classes
- Defines: Auto-categorization, merchant detection, chat response methods

**AutoCategorizer (Provider-specific):**
- Purpose: Handle AI-based transaction categorization
- Examples: `Provider::Anthropic::AutoCategorizer`, `Provider::Openai::AutoCategorizer`
- Pattern: Instantiated with client, model, transactions, categories
- Returns: Array of `Provider::LlmConcept::AutoCategorization` results

**LearnedPattern:**
- Purpose: Store user's manual categorization for pattern matching
- Location: `app/models/learned_pattern.rb`
- Pattern: ActiveRecord model with pattern matching logic
- Used by: `LearnedPatternMatcher` for rule-based categorization

**Enrichable:**
- Purpose: Manage attribute enrichment with locking
- Location: `app/models/concerns/enrichable.rb`
- Pattern: Concern included by Transaction, Merchant models
- Methods: `enrichable?`, `enrich!`, `enriched?`, `locked_attributes`

## Entry Points

**Controllers:**
- `Transactions::AiCategorizationsController` - Individual transaction categorization
- `Transactions::BulkAiCategorizationsController` - Bulk categorization
- `Settings::AiPromptsController` - AI prompt configuration
- `ChatsController` - AI chat interface
- `Api::V1::ChatsController` - API endpoint for chat

**Background Jobs:**
- `AutoCategorizeJob` - Queued categorization (`app/jobs/auto_categorize_job.rb`)
- `AutoDetectMerchantsJob` - Merchant name detection
- `AssistantResponseJob` - AI chat responses

**Models:**
- `Family::AutoCategorizer` - Main categorization orchestrator
- `Family::AutoMerchantDetector` - Merchant detection orchestrator
- `Assistant` - AI chat assistant logic

## Error Handling

**Strategy:** Provider errors bubble up, caught at controller/job level with user-friendly messages

**Patterns:**
- Provider-specific error classes: `Provider::Anthropic::Error`, `Provider::Openai::Error`
- Controller rescues: `rescue Family::AutoCategorizer::Error` with flash messages
- Generic rescue clauses in auto-categorizers with logging
- Langfuse error tracking for observability

## Cross-Cutting Concerns

**Observability:**
- Langfuse integration for all LLM calls
- `LlmUsage` model tracks token counts, costs, metadata
- Traces for: `chat_response`, `auto_categorize`, `auto_detect_merchants`

**Usage Tracking:**
- `LlmUsage` table records: provider, model, operation, tokens, estimated_cost
- Indexed by family_id for per-usage tracking

**Multi-tenancy:**
- `Current.family` for scoping (not current_family)
- All AI operations scoped to family

**Security:**
- API keys stored encrypted in database
- Environment variables for initial configuration
- No hardcoded credentials

---

*Architecture analysis: 2026-01-11*
*Update when major patterns change*
