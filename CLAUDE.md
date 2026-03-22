# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Development server (port 3001) + CSS watcher
bin/dev

# Tests
bin/rails test                    # All tests
bin/rails test test/models/       # Single directory
bin/rails test test/models/article_test.rb  # Single file
bin/rails test:system             # System tests (Capybara/Selenium)

# Linting & security
bin/rubocop                       # Ruby style (omakase)
bin/brakeman --no-pager           # Security scan

# Database
bin/rails db:migrate
bin/rails db:seed
```

## Architecture

**EDO** is a Rails 8 content publishing platform. The central concept is a **polymorphic `Story`** model that wraps content types (currently `Article`, `Video`) for unified display.

### Content flow

1. An `Article` is created with status `:draft` → `:review` → `:published`
2. Publishing an article triggers a callback that creates an associated `Story` record (`storyable: polymorphic`)
3. `StoriesController#index` (root route) queries `Story` to assemble the homepage

### Key models

| Model | Notes |
|-------|-------|
| `Article` | Core content: rich text (`has_rich_text :content`), `has_one_attached :featured_image`, FriendlyId slugs, reading time, status enum |
| `Story` | Polymorphic wrapper around `Article`/`Video`; drives homepage |
| `Author` | Soft-deleted via `deleted_at`; roles: writer/editor/admin |
| `Category` / `Tag` | Categorization; articles tagged via join tables |
| `Video` | Standalone video content type |

### Infrastructure

Rails 8 Solid stack — no external Redis/Memcached:
- **Solid Cache** → `edo_production_cache` DB
- **Solid Queue** → `edo_production_queue` DB
- **Solid Cable** → `edo_production_cable` DB

Database config in `config/database.yml` reflects this multi-DB setup.

### Frontend

- **Hotwire** (Turbo + Stimulus) — no React/Vue
- **Tailwind CSS** — dark mode enabled, custom design tokens, plugins: forms, typography, container-queries
- **Import maps** — no webpack/bundler; JS managed via `config/importmap.rb`
- **ViewComponent** — reusable UI components live in `app/components/`
- **Action Text** — rich text editor backed by Active Storage

### Notable patterns

- **Slug generation**: FriendlyId on `Article` and `Tag` (via `before_validation` callback)
- **Reading time**: Calculated automatically on save in `Article`
- **Pagination**: Kaminari, hardcoded `paginates_per 3` on Article
- **Search**: Full-text across title, subtitle, excerpt, and tags in `ArticlesController`
- **Services**: `app/services/instagram_service.rb` — external Instagram API via HTTParty
- **Story creation callback**: Publishing an article auto-creates its `Story` record

### Deployment

Kamal (`config/deploy.yml`) with Docker. Production targets require SSL. Run `bin/kamal` for deployment commands.
