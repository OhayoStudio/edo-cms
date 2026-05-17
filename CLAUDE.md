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

**EDO CMS** is a Rails 8 content publishing template. The central concept is a polymorphic `Story` model that wraps content types (`Article`, `Video`) for unified display on the homepage.

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
| `About` / `Colophon` | Singleton editorial pages, rich text via Lexxy |
| `Setting` | Singleton record driving site name, tagline, logo, colors, nav, social, analytics, newsletter |

### Branding & configuration

This is a brand-agnostic template. Each fork configures its identity through `/admin/settings` instead of editing source:

- **Site name, tagline, meta description, contact email** → `Setting`
- **Logos (light/dark), favicon, OG default image** → `Setting` (Active Storage)
- **Theme colors** → `Setting#theme_colors`, injected as `--cms-*` CSS variables by `cms_theme_style_tag` (helper in `app/helpers/settings_helper.rb`)
- **Navigation** → `Setting#nav_items` (primary + footer)
- **Social links** → `Setting#social_links`
- **Analytics provider** (currently Umami) → `Setting#analytics_*`
- **Newsletter** → `Setting#newsletter_*` (form action; provider field is informational)

Infrastructure stays in ENV / config:

- `APPLICATION_HOST` → public hostname (used by sitemap, meta tags, OG URLs)
- `RAILS_MASTER_KEY`, `EDO_CMS_DATABASE_PASSWORD`, `GCS_BUCKET`, `GCS_CREDENTIALS_PATH`, etc.
- `YOUTUBE_API_KEY` enables the YouTube metadata fetch in admin (optional)

See `.env.production.example` for the full list.

### Infrastructure

Rails 8 Solid stack — no external Redis/Memcached:
- **Solid Cache** → `edo_cms_production_cache` DB
- **Solid Queue** → `edo_cms_production_queue` DB
- **Solid Cable** → `edo_cms_production_cable` DB

Database config in `config/database.yml` reflects this multi-DB setup.

### Frontend

- **Hotwire** (Turbo + Stimulus) — no React/Vue
- **Tailwind CSS** — dark mode enabled, theme colors driven by Setting via CSS custom properties
- **Import maps** — no webpack/bundler; JS managed via `config/importmap.rb`
- **ViewComponent** — reusable UI components live in `app/components/`
- **Lexxy** — rich text editor backed by Active Storage / Action Text

### Notable patterns

- **Slug generation**: FriendlyId on `Article` and `Tag`
- **Reading time**: Auto-calculated on save in `Article`
- **Pagination**: Kaminari, `paginates_per 10`
- **Search**: Full-text across title, subtitle, excerpt, tags in `ArticlesController`
- **Settings cache**: `Setting.instance` is `Rails.cache`-memoized; `after_save`/`after_touch` invalidate

### Deployment

Kamal (`config/deploy.yml`) with Docker. `config/deploy.yml` is templated with ENV placeholders — replace `service`, `image`, `hosts`, `registry`, and `volumes` for your project before deploying.

## Local development dependencies

```bash
brew install libpq postgresql
```

`libpq` is required for the `pg` gem to compile.

Optional: Postgres.app (https://postgresapp.com) if you'd rather not run Postgres via Homebrew.
