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
bin/dev                      # http://localhost:3001
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

## License

MIT.
