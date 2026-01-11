# Technology Stack

**Analysis Date:** 2026-01-11

## Languages

**Primary:**
- Ruby 3.4.7 - All application code (confirmed in `.ruby-version`)

**Secondary:**
- JavaScript/TypeScript - Minimal frontend code (linting/formatting tools in `package.json`)

## Runtime

**Environment:**
- Rails 7.2.2 - Web framework (`Gemfile`)
- PostgreSQL - Database (via `pg` gem)
- Redis - Background jobs and caching
- Puma - Web server

**Package Manager:**
- Bundler - Ruby dependencies (`Gemfile`, `Gemfile.lock`)
- npm - JavaScript dependencies (`package.json`, `package-lock.json`)

## Frameworks

**Core:**
- Rails 7.2.2 - Full-stack web framework
- Hotwire Stack (Turbo, Stimulus Rails) - Reactive UI without heavy JavaScript
- ViewComponent - Reusable UI components
- Sidekiq - Background job processing with sidekiq-cron for scheduled tasks

**Testing:**
- Minitest - Rails' built-in testing framework
- Capybara - System tests
- VCR (Video Cassette Recorder) - External API mocking
- Mocha - Mocking and stubbing
- SimpleCov - Test coverage reporting

**Build/Dev:**
- Propshaft - Asset pipeline
- Importmap - JavaScript module loading (no Webpack)
- Tailwind CSS v4.x - Styling with custom design system
- RuboCop - Ruby linting (inherits from rubocop-rails-omakase)

## Key Dependencies

**Critical (AI/ML Related):**
- anthropic ~> 1.16.0 - Anthropic Claude API client (`app/models/provider/anthropic.rb`)
- ruby-openai - OpenAI API client (`app/models/provider/openai.rb`)
- langfuse-ruby ~> 0.1.4 - LLM observability and tracing
- faraday - HTTP client with retry/multipart support

**Critical (Financial Data):**
- plaid - Bank account aggregation
- stripe - Payment processing
- money - Monetary value handling

**Infrastructure:**
- pg - PostgreSQL database driver
- redis - Redis client for caching/jobs
- sidekiq - Background job processing
- puma - Web server

## Configuration

**Environment:**
- `.env` - Local development environment variables
- `.env.example` - Template for self-hosting
- `.env.local.example` - Local development with AI settings
- `.env.test` - Test environment
- Rails credentials (`config/credentials.yml.enc`) - For sensitive data
- Active Record Encryption - For encrypting API keys in database

**Key AI Configuration Variables:**
- `OPENAI_ACCESS_TOKEN` - OpenAI API key
- `OPENAI_URI_BASE` - Custom OpenAI-compatible endpoint
- `OPENAI_MODEL` - Model name override
- `ANTHROPIC_API_KEY` - Anthropic API key (inferred, not in .env.example)
- `LANGFUSE_PUBLIC_KEY` - Langfuse tracing
- `LANGFUSE_SECRET_KEY` - Langfuse tracing
- `LANGFUSE_HOST` - Langfuse host URL

**Build:**
- `.rubocop.yml` - RuboCop configuration (rubocop-rails-omakase)
- `tailwind.config.js` - Tailwind CSS configuration
- `importmap.rb` - JavaScript module mapping

## Platform Requirements

**Development:**
- macOS/Linux/Windows (any platform with Ruby)
- PostgreSQL 14+
- Redis 7+
- Node.js 18+ (for asset compilation)
- Python 3.9+ (for some build tools)

**Production:**
- Docker support (docker-compose for self-hosted)
- PaaS compatible (Heroku, Render, Fly.io)
- Managed mode (team-operated servers) or Self-Hosted mode

---

*Stack analysis: 2026-01-11*
*Update after major dependency changes*
