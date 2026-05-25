# Contributing to EDO CMS

Thanks for the interest — but a quick heads-up before you spend time:

## This template is maintained, not collaborative

EDO CMS exists primarily to power [OhayoStudio](https://github.com/OhayoStudio)'s brand sites. We publish it openly because:

- It's a useful reference for anyone building a similar Rails-8-based content template.
- We're happy for forks to track upstream and pick up improvements as they land.
- We learn things from outside eyes on the code.

We **don't** accept external pull requests. Not because we don't appreciate them, but because every PR comes with maintenance overhead (review, CI fix-up, backwards-compat thinking, downstream propagation to brand forks) that we can't sustainably absorb. Closing a PR you spent time on would be worse than being clear upfront.

## What's useful

- **Bug reports** — open an issue. If something demonstrably breaks the template's published behavior (clean clone → `bin/setup` → broken), we want to know.
- **Security disclosures** — see [`SECURITY.md`](SECURITY.md).
- **Forks** — go for it. "Use this template" is enabled. Carry on as you like; we don't expect anything back.
- **Questions about *how* something works** — open an issue tagged `question`; we'll answer when we can.

## What's not useful

- Pull requests of any kind (we'll close politely).
- Feature requests not tied to a concrete bug in current behavior.
- Style debates (we run Rubocop omakase; that's the style).

## If you're using this as a starting point

The `spawn-edo-site` workflow we use internally is described in the [README](README.md). The short version: clone, rebrand via `/admin/settings`, deploy. If you build something interesting on top, we'd love to see it — drop a link in an issue.
