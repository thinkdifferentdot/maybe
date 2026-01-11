# External Integrations

**Analysis Date:** 2026-01-11

## APIs & External Services

**AI/LLM Providers:**
- **Anthropic Claude** - Primary LLM provider for auto-categorization and chat
  - SDK/Client: `anthropic` gem ~> 1.16.0
  - Auth: `ANTHROPIC_API_KEY` env var (not in .env.example, inferred)
  - Default model: `claude-sonnet-4-5-20250929` (`app/models/provider/anthropic.rb:9`)
  - Endpoints used: Messages API (chat, auto-categorize, merchant detection)

- **OpenAI GPT** - Alternative LLM provider
  - SDK/Client: `ruby-openai` gem
  - Auth: `OPENAI_ACCESS_TOKEN` env var
  - Default model: `gpt-4.1` (`app/models/provider/openai.rb:9`)
  - Custom endpoints: Supported via `OPENAI_URI_BASE` (Ollama, OpenRouter, etc.)

**Financial Data:**
- **Plaid** - Bank account aggregation and transaction sync
  - SDK/Client: `plaid` gem
  - Auth: Environment variables (managed per deployment)
  - Endpoints used: Item exchange, transactions, balances

- **SimpleFIN** - Open banking protocol support
  - Integration: Custom implementation in `app/models/simplefin_*.rb`
  - Auth: Access token via environment

- **Stripe** - Payment processing and subscriptions
  - SDK/Client: `stripe` gem
  - Auth: `STRIPE_SECRET_KEY` env var

**Market Data:**
- **Twelve Data** - Exchange rates and stock prices
  - Integration: Custom API client
  - Auth: API key via environment

- **Yahoo Finance** - Alternative market data source
  - Integration: Custom scraping/API

**Other Services:**
- **Brandfetch** - Bank/merchant logo fetching
  - Integration: HTTP client for logo URLs

- **Twilio** - SMS (if configured)
  - SDK/Client: `twilio-ruby` gem

## Data Storage

**Databases:**
- **PostgreSQL** - Primary data store
  - Connection: `DATABASE_URL` env var
  - Client: `pg` gem with ActiveRecord ORM
  - Migrations: `db/migrate/`
  - Key tables: `llm_usages`, `transactions`, `categories`, `merchants`

**File Storage:**
- **AWS S3 / Cloudflare R2** - User uploads
  - SDK/Client: Active Storage with S3 adapter
  - Auth: AWS credentials via environment
  - Buckets: Configured per deployment

**Caching:**
- **Redis** - Session storage, background jobs
  - Connection: `REDIS_URL` env var
  - Client: `redis` gem
  - Uses: Sidekiq job queue, cache store

## Authentication & Identity

**Auth Provider:**
- **Self-hosted authentication** - User model with session-based auth
  - Implementation: Rails sessions with secure cookies
  - Token storage: httpOnly cookies
  - Session management: Rails session middleware

**Multi-tenancy:**
- **Family-based scoping** - `Current.family` (not `current_family`)
  - All data scoped to family
  - AI operations isolated per family

## Monitoring & Observability

**Error Tracking:**
- **Rails logging** - Standard Rails.logger
  - Logs to stdout/stderr (captured by infrastructure)
  - No Sentry integration detected

**AI Observability:**
- **Langfuse** - LLM tracing and analytics
  - SDK/Client: `langfuse-ruby` gem ~> 0.1.4
  - Auth: `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`
  - Host: `LANGFUSE_HOST` (default: cloud.langfuse.com)
  - Traces: All LLM operations (chat, auto_categorize, auto_detect_merchants)
  - Features: Request/response tracking, cost estimation, latency measurement

**Usage Tracking:**
- **LlmUsage model** - Internal AI usage tracking
  - Table: `llm_usages`
  - Fields: provider, model, operation, prompt_tokens, completion_tokens, total_tokens, estimated_cost, metadata
  - Indexes: family_id, created_at, operation

## CI/CD & Deployment

**Hosting:**
- **Self-hosted** (Docker Compose) or **Managed** mode
  - Deployment: Docker containers with docker-compose
  - Environment vars: Configured per deployment type

**CI Pipeline:**
- **GitHub Actions** (if configured)
  - Workflows: `.github/workflows/`
  - Tests: `bin/rails test`
  - Linting: `bin/rubocop`

## Environment Configuration

**Development:**
- Required env vars: `DATABASE_URL`, `REDIS_URL`
- AI vars: `OPENAI_ACCESS_TOKEN` or `ANTHROPIC_API_KEY`
- Langfuse: Optional but recommended for AI debugging
- Secrets location: `.env` (gitignored), team shared via 1Password

**Self-Hosted:**
- Environment-specific: Separate database and Redis
- AI provider: User-configurable via UI
- Configuration via Settings → Self-Hosting → AI Provider

**Managed:**
- Secrets management: Managed infrastructure
- AI provider: Configured by operator

## Webhooks & Callbacks

**Incoming:**
- **Stripe webhooks** - Subscription updates (if used)
  - Endpoint: `/webhooks/stripe`
  - Verification: Signature validation

**Outgoing:**
- None detected (application is web-based, no outgoing webhooks)

## AI/ML Configuration

**Provider Selection:**
- `Provider::Registry` - Manages available providers by concept (`:llm`)
- Fallback order: Settings → Environment → Default
- UI override: Settings → Self-Hosting → AI Provider

**Model Configuration:**
- Anthropic models: `claude-sonnet-4-5-20250929` (default)
- OpenAI models: `gpt-4.1` (default), `gpt-5`, `gpt-4o-mini`
- Custom models: Via `OPENAI_MODEL` for OpenAI-compatible endpoints

**Cost Tracking:**
- Token counts tracked in `llm_usages` table
- Estimated costs calculated per operation
- Langfuse provides additional cost analytics

---

*Integration audit: 2026-01-11*
*Update when adding/removing external services*
