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

```bash
git clone <your-fork-url> my-cms
cd my-cms

bin/setup                    # bundle, install JS, create + migrate + seed databases
bin/dev                      # http://localhost:3001
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
