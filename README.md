# EDO CMS

> **Why is this public?** This repo powers [OhayoStudio](https://github.com/OhayoStudio)'s brand sites — pokeibo, ohayostudio, and any future ones. It's open so others can use it as a reference or starting point, and so the upstream/fork relationship between our own sites stays inspectable. We **don't** accept external pull requests (see [CONTRIBUTING.md](CONTRIBUTING.md)); bug reports as issues are welcome.

A Rails 8 content publishing template designed to be **forked into branded sites**. Articles, videos, authors, categories, tags — with a polymorphic `Story` wrapper that drives a magazine-style homepage. Brand-agnostic: identity (name, palette, fonts, logos, nav, copy) is driven by a single `Setting` model and editable from `/admin/settings`. Infrastructure stays in `.env`.

Bilingual out of the box (EN + JA), with locale-scoped routes and editor-overridable strings.

## Stack

- Rails 8.1 (Solid Cache / Queue / Cable — no Redis or Memcached)
- PostgreSQL (multi-DB: app + Solid Cache + Solid Queue + Solid Cable)
- Hotwire (Turbo + Stimulus) — no React/Vue
- Tailwind CSS v4 — `@theme` block cascades through `--cms-*` runtime CSS variables, so every utility (`bg-cream`, `text-sage-deep`, `font-display`, …) re-themes whenever Settings change
- Propshaft + importmap-rails — no Node bundler
- ViewComponent
- Lexxy rich-text editor (Action Text / Active Storage backed)
- Active Storage (local in dev, GCS in production)
- Kamal + Docker for deployment
- Optional: self-hosted Umami analytics, Sentry error reporting

## Getting started

The easiest way: click the green **Use this template** button at the top of this repo to create your own copy under your account/org. Then clone *your* new repo locally:

```bash
git clone https://github.com/<you>/<your-repo>.git
cd <your-repo>

bin/setup                    # bundle, install JS, create + migrate + seed databases
bin/dev                      # http://localhost:3107
```

If you'd rather track upstream and pull future template updates, clone directly and rewire remotes:

```bash
git clone https://github.com/OhayoStudio/edo-cms.git my-cms
cd my-cms
git remote rename origin upstream                          # keep a read-only feed of template updates
git remote add origin https://github.com/<you>/<your-repo>.git
git push -u origin main
```

The seed creates an admin user (default `admin@example.com` with a random password printed to STDOUT — override with `ADMIN_EMAIL` and `ADMIN_PASSWORD`).

Log in at `/admin`, then visit `/admin/settings` to configure your site name, logos, colors, fonts, nav, social links, and analytics.

### Demo content (optional)

To plant a handful of articles + videos with thumbnails so the homepage has something to show on a fresh install:

```bash
SEED_DEMO_CONTENT=1 bin/rails db:seed
```

The seed is idempotent and safe to re-run. Defined in `db/seeds/demo.rb`. Leave the env var unset in production.

## Configuration

Everything brand-specific lives in `/admin/settings` — no code edits needed to spin up a new site.

### Branding

- **Site name, tagline, contact email, meta description**
- **Logos** — light + dark, used in the header and footer
- **Favicon** — used for `<link rel="icon">`, `apple-touch-icon`, and PWA manifest icons. Drives `schema.org` Organization logo when no separate logo is uploaded.
- **OG default image** — used for `og:image` when an article/video has no specific image of its own.

All of these are Active Storage attachments. Layout, meta-tags, and PWA manifest source from them dynamically with `public/` fallbacks for fresh installs.

### Theme colors

7 editable slots → injected as `--cms-*` CSS variables → Tailwind's `@theme` block cascades them into every named utility:

| Slot | Drives |
|---|---|
| `primary` | Headings, italic emphasis, primary CTAs (Tailwind: `text-sage-deep`) |
| `primary_dark` | Hover / dark contrast |
| `secondary` | Gold/peach accents (Tailwind: `bg-peach`, `text-peach-deep`) |
| `accent` | Borders, dividers (Tailwind: `border-rule`) |
| `background` | Page background (Tailwind: `bg-cream`) |
| `text_primary` | Softer text emphasis (Tailwind: `text-ink-soft`) |
| `text` | Body text (Tailwind: `text-ink`) |

Edit at `/admin/settings → Theme colors`. Changes apply on hard-reload — no deploy.

### Typography

5 editable font roles, all wired to Google Fonts dynamically:

- `display` — primary sans
- `serif` — editorial serif (used for italics; ital axis loaded automatically)
- `jp`, `jp_serif` — Japanese-text fonts
- `mono` — code / metadata

Edit at `/admin/settings → Typography`. Type the exact Google Fonts family name (e.g. `Instrument Serif`) — the layout's `<link>` to fonts.googleapis.com is rebuilt from this list on every render.

### Navigation

Curated key registry — admin types **keys** (one per line) into the Primary/Footer nav textareas; the renderer maps each to a translated label and locale-aware path. Available keys are listed under the textareas. Add new ones by appending to `nav_registry` in `app/helpers/settings_helper.rb` plus a matching `nav.primary.<key>` label in `config/locales/shared/nav.<locale>.yml`.

### i18n + translation overrides

- Locale-scoped routes (`/en/...`, `/ja/...`).
- Locale resolution: URL param → cookie → `Accept-Language` → default.
- `LocalizedContent` concern for the About + Colophon pages (per-locale rich text).
- **Editor-overridable strings** — a whitelist of i18n keys (`Setting::EDITABLE_TRANSLATION_KEYS`) is exposed at `/admin/settings → Translations`. Editors can rewrite nav labels per-locale without touching YAMLs. Anything outside the whitelist is silently dropped.

Extend the whitelist in your fork to expose more keys (e.g. landing-page eyebrows). Keep `_html` keys and large copy blocks out — raw markup in the form is a footgun and the editor doesn't scale past ~30 rows.

### Content

- **Articles, videos, authors, categories, tags** — full CRUD at `/admin/articles`, `/admin/videos`, etc.
- **About + Colophon** — singleton editorial pages, bilingual; edit at `/admin/abouts/edit`, `/admin/colophons/edit`.
- **Static markdown pages** — `/terms`, `/privacy` (extend with custom slugs). Content lives in `db/seeds/pages/<slug>.<locale>.md`, served by `PagesController`. Whitelist gate: add a slug to `PagesController::SLUGS` plus a route in `config/routes.rb`.

### Analytics + newsletter

- **Analytics** → Umami toggle + Website ID + host. See the Analytics section below.
- **Newsletter** → provider hint + form action URL. The About page renders an inline signup form that posts to this action.

### Infrastructure (`.env`)

See `.env.production.example` for the canonical list. `RAILS_MASTER_KEY`, `<your>_DATABASE_PASSWORD`, `APPLICATION_HOST`, `KAMAL_REGISTRY_PASSWORD` are required. GCS, YouTube API, Sentry, Umami are optional.

## Tests

```bash
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

> **Note:** the test suite has known failures on `main` (the template ships starter tests; brand forks are expected to extend or replace them). Rubocop + Brakeman pass.

## Deployment

Kamal config in `config/deploy.yml` is env-templated; the deploy scripts in `bin/deploy-{production,staging}` are env-driven (`REGISTRY_IMAGE`, `DEPLOY_HOST`, `APPLICATION_HOST`, …). Fill the `.env.production` values, then:

```bash
bin/deploy-production
```

CI on GitHub Actions runs Brakeman (security), `importmap audit` (JS deps), and Rubocop on every PR. Dependabot watches Bundler / GitHub Actions / Docker weekly with patch+minor grouping.

## Analytics (Umami)

EDO CMS ships with a self-hosted [Umami](https://umami.is) setup as a Kamal accessory — privacy-friendly, cookie-less page-view + custom-event tracking. Two containers: a dedicated Postgres for Umami's data, and the Umami web app routed through the Kamal proxy on a subdomain.

**1. Set deploy-host env vars** (see `.env.production.example`):

```bash
UMAMI_HOST=analytics.example.com    # subdomain you'll point at the server
UMAMI_DB_PASSWORD=<random>          # postgres password for the umami role
UMAMI_APP_SECRET=<random 32+ chars> # `rails secret` works
```

Point an `A` record for `UMAMI_HOST` at the deploy host.

**2. Boot the accessories:**

```bash
bin/kamal accessory boot umami-db
bin/kamal accessory boot umami
```

**3. First-time Umami setup:** open `https://$UMAMI_HOST`, log in with `admin` / `umami`, change the password, create a "Website" entry for your domain. Copy the generated **Website ID**.

**4. Wire it into the CMS:** in `/admin/settings → Analytics`, tick **Enable Umami**, paste the Website ID, and set the host to `$UMAMI_HOST`. The snippet renders in any non-test environment and is automatically scoped to `APPLICATION_HOST` via `data-domains`, so unset-host dev traffic is ignored unless you also set `APPLICATION_HOST` locally.

**Custom events:** clicks on the homepage story cards fire `story_click` (with `position` and `title`); the newsletter submit button fires `newsletter_signup`. Add more by sprinkling `data-umami-event="..."` (plus optional `data-umami-event-<key>="..."` props) on any clickable element — no JS required.

**Local testing:** a `docker-compose.umami.yml` ships at the repo root so you can verify the integration before going to prod:

```bash
docker compose -f docker-compose.umami.yml up -d
# open http://localhost:3006 — log in as admin / umami, change pw,
# create a website, copy its Website ID.
```

Then in `/admin/settings → Analytics`: tick **Enable Umami**, paste the Website ID, and set host to `localhost:3006`. The helper picks `http` automatically for local hosts.

## License

MIT.
