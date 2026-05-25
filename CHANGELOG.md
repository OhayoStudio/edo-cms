# Changelog

Notable changes to EDO CMS. Brand forks track this file to know what's worth cherry-picking.

This project doesn't use tagged releases — `main` is the canonical state. Entries are reverse-chronological and grouped loosely by surface.

## Unreleased

_Polish for going public:_ added `CONTRIBUTING.md`, `SECURITY.md`, this changelog, and a "Why is this public?" header in the README. No code changes.

## 2026-05 — local-dev + propshaft fixes

- **Fix**: `cms_favicon_url` / `cms_logo_or_favicon_url` were calling `rails_representation_url` on raw ActiveStorage attachments, which silently returned nil and crashed Propshaft. Switched to `url_for`; dropped `favicon_link_tag` in layouts (it routes through Propshaft regardless of input). [`a17ad0e`, `ad8e878`]
- **Dev port**: `bin/dev` now binds to `3107` (was `3005`, which was getting claimed by other local servers).
- **Lexxy**: pinned to `~> 0.9.3.beta` (0.9.12 introduced an incompatibility upstream).
- **Rubocop**: layout cleanup in `MetaTagsHelper`.

## 2026-05 — Setting-driven branding + design integration

- **Favicon, logos, OG image** now sourced from `Setting` attachments first, with `public/` fallbacks for fresh installs. Layout, admin layout, PWA manifest, and `schema.org` JSON-LD all read from Setting. [`669c3e1`]
- **Replaced SepiaBraun placeholder assets** with a generic edo-cms-branded mark so the template doesn't ship someone else's brand.
- **Typography editor**: new `Setting#fonts` JSONB column + `FONT_DEFAULTS` covering 5 roles (display, serif, jp, jp_serif, mono). Layout's Google Fonts `<link>` is built dynamically — pick a font in admin, no deploy needed.
- **Tailwind `@theme` rewired** through `--cms-*` runtime vars so every utility (`bg-cream`, `text-sage-deep`, `font-display`) re-themes when Settings change.
- **Surplus design tokens** (sky-soft, sun-deep, ink-muted, etc.) live in `app/assets/stylesheets/theme_extras.css` and load alongside the main theme stylesheet.

## 2026-05 — Brand-leakage cleanup

- **Genericized** `bin/deploy-{production,staging}` — replaced hardcoded SepiaBraun URLs / `ghcr.io/ohayostudio/edo` image tags / production IPs with env-driven placeholders (`REGISTRY_IMAGE`, `DEPLOY_HOST`, `APPLICATION_HOST`). [`5e2c15d`]
- **`.github/ISSUE_TEMPLATE/article.yml`** — dropped brand-specific wording, hardcoded category list, Japan-related field, and auto-assignment. Now a general-purpose article-tracking template.
- **`.gitignore`** — removed vestigial `sepiabraun*.json` patterns.
- **Deleted** `script/{prepare_articles,search_sources,flickr_auth}.rb` — personal article-prep / OAuth tools with hardcoded paths or unused dependencies.

## 2026-05 — Optional demo content

- **`db/seeds/demo.rb`** — plants an Author, a Category, 5 articles with solid-color placeholder images, and 5 videos with real YouTube thumbnails (fair-use linking; replace with your own content). Gated by `SEED_DEMO_CONTENT=1` so production stays minimal. [`dc33c01`]

## 2026-05 — Infrastructure tuning

- **Dependabot**: weekly schedule, patch+minor grouped per ecosystem, Docker ecosystem added. [`9583bb3`]
- **`Author#status` defaults to `:active`** via `after_initialize` — mirrors the `Article` pattern, prevents `humanize` crashes when callers don't set the status explicitly. [`76c0f43`]

## 2026-05 — Footer + dark mode

- **Footer nav** now supports `terms` + `privacy` keys via the nav registry (EN + JA labels). [`59b2200`]
- **Dark-mode variants** for the "Latest stories" footer on `/about`.
- **Dark-mode flash** fixed — inline script before stylesheets sets the right class on `<html>` so first paint matches the user's saved preference. [`20875f4`]

## 2026-05 — Umami analytics

- **Self-hosted Umami** as a Kamal accessory (Umami app + dedicated Postgres, routed via Kamal proxy on a subdomain). [`c93d1c7`]
- **Local docker-compose** stack at `docker-compose.umami.yml` for dev testing.
- **Admin toggle** at `/admin/settings → Analytics` — enable Umami + paste Website ID + host.
- **Custom events** via native `data-umami-event` on story cards (`story_click`) and the newsletter submit button (`newsletter_signup`). No JS required.

## 2026-04 — CMS-editable i18n

- **`Setting::EDITABLE_TRANSLATION_KEYS`** whitelist — admin can override specific i18n strings per locale at `/admin/settings → Translations` without touching YAMLs or redeploying. Anything outside the whitelist is silently dropped. [`5eeeaaf`]
- **Curated nav registry** — admin picks **keys** (one per line) into Primary/Footer nav textareas; the renderer maps each to a translated label and locale-aware path. Replaces the old free-text URL pairs. [`e3c16c1`]
- **Default palette** swapped from brand brown to the calm-morning sage / ink palette. [`d7c03d1`]
- **`LocalizedContent` concern** + bilingual About / Colophon — per-locale rich text columns. [`90d2ab9`]

## 2026-04 — Static markdown pages

- **`PagesController`** — serves bilingual markdown from `db/seeds/pages/<slug>.<locale>.md`. Slug whitelist gate in the controller; routes added per page. Ships with `terms` + `privacy` starters; extend by appending to the whitelist + dropping new `.md` files into the seed directory. [`4c1307c`]

## Earlier

The pre-2026-04 history is the original brand-coupled lineage — kept for archaeological purposes but not summarized here. Anything you want from before the [`4c1307c`] split point should be cherry-picked deliberately, not by date.
