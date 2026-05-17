# EDO CMS

A Rails 8 content publishing template. Articles, videos, authors, categories, tags — with a polymorphic `Story` wrapper driving a magazine-style homepage. Brand-agnostic: site name, tagline, logo, colors, navigation, and social links are configured at `/admin/settings`. Infrastructure (hosts, storage, DB) is configured via ENV.

## Stack

- Rails 8 (Solid Cache / Queue / Cable — no Redis)
- PostgreSQL
- Hotwire (Turbo + Stimulus)
- Tailwind CSS
- ViewComponent
- Active Storage + Action Text (rich text via Lexxy editor)
- Kamal for deployment

## Getting started

```bash
bin/setup
bin/dev                  # http://localhost:3001
```

Then log in at `/admin` and configure your site at `/admin/settings`.

## Tests

```bash
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```
