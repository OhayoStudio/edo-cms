# EDO CMS

A Rails 8 content publishing template. Articles, videos, authors, categories, tags — with a polymorphic `Story` wrapper that drives a magazine-style homepage. Brand-agnostic: configure site name, tagline, logo, colors, navigation, and social links from `/admin/settings`. Infrastructure stays in `.env`.

## Stack

- Rails 8 (Solid Cache / Queue / Cable — no Redis)
- PostgreSQL
- Hotwire (Turbo + Stimulus)
- Tailwind CSS, theme driven by CSS custom properties from `Setting#theme_colors`
- ViewComponent
- Lexxy rich-text editor (Action Text / Active Storage backed)
- Kamal for deployment

## Getting started

The easiest way: click the green **Use this template** button at the top of this repo to create your own copy under your account/org. Then clone *your* new repo locally:

```bash
git clone https://github.com/<you>/<your-repo>.git
cd <your-repo>

bin/setup                    # bundle, install JS, create + migrate + seed databases
bin/dev                      # http://localhost:3005
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

Log in at `/admin`, then visit `/admin/settings` to configure your site name, logos, colors, nav, and social links.

## Configuration

- **Brand / theme** → `/admin/settings`
- **Editorial pages** → `/admin/abouts/edit`, `/admin/colophons/edit`
- **Content** → `/admin/articles`, `/admin/videos`, `/admin/authors`, `/admin/categories`, `/admin/tags`
- **Infrastructure** → `.env` (see `.env.production.example` for the full list)

## Tests

```bash
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

## Deployment

Kamal config lives in `config/deploy.yml`. Replace the placeholders (`service`, `image`, `hosts`, `registry`, `volumes`) with your project values before running `bin/kamal deploy`.

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

**4. Wire it into the CMS:** in `/admin/settings` → Analytics, tick **Enable Umami**, paste the Website ID, and set the host to `$UMAMI_HOST`. The tracking snippet only renders in `production` and is automatically scoped to `APPLICATION_HOST` via `data-domains`, so dev/preview traffic is ignored.

**Custom events:** clicks on the homepage story cards fire `story_click` (with `position` and `title`); the newsletter submit button fires `newsletter_signup`. Add more by sprinkling `data-umami-event="..."` (plus optional `data-umami-event-<key>="..."` props) on any clickable element — no JS required.

**Local testing:** a `docker-compose.umami.yml` ships at the repo root so you can verify the integration before going to prod:

```bash
docker compose -f docker-compose.umami.yml up -d
# open http://localhost:3006 — log in as admin / umami, change pw,
# create a website, copy its Website ID.
```

Then in `/admin/settings` → Analytics: tick **Enable Umami**, paste the Website ID, and set host to `localhost:3006`. The snippet renders in any non-test env and picks `http` automatically for local hosts.

## License

MIT.
