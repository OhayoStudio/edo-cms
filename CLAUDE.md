# CLAUDE.md

## Commands

```bash
# Development server (port 3005) + CSS watcher
bin/dev
```

## Architecture

**EDO CMS** is a Rails 8 content publishing template. The central concept is a polymorphic `Story` model that wraps content types (`Article`, `Video`) for unified display on the homepage.

### Content flow

1. An `Article` is created with status `:draft` → `:review` → `:published`
2. Publishing an article triggers a callback that creates an associated `Story` record (`storyable: polymorphic`)
3. `StoriesController#index` (root route) queries `Story` to assemble the homepage

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

### Notable patterns

- **Settings cache**: `Setting.instance` is `Rails.cache`-memoized; `after_save`/`after_touch` invalidate

### Deployment

Kamal (`config/deploy.yml`) with Docker. `config/deploy.yml` is templated with ENV placeholders — replace `service`, `image`, `hosts`, `registry`, and `volumes` for your project before deploying.

## Local development dependencies

```bash
brew install libpq postgresql
```

`libpq` is required for the `pg` gem to compile.

Optional: Postgres.app (https://postgresapp.com) if you'd rather not run Postgres via Homebrew.
