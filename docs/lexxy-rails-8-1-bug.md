# Lexxy + Rails 8.1: pending upstream fix

## Status (2026-05-17)

- **Bug:** `lexxy 0.9.3.beta` (and current `main`) raises `NoMethodError: undefined method '+' for true` on Rails 8.1.
- **Workaround in this repo:** [`config/initializers/lexxy_rails_8_1_compat.rb`](../config/initializers/lexxy_rails_8_1_compat.rb). Delete it once Lexxy ships a fix.
- **Upstream PR:** not opened yet. We searched `basecamp/lexxy` issues + PRs for `sanitizer_allowed_tags`, `allowed_tags`, `NoMethodError`, `action_text_content` — zero matches.

## What's wrong

In `lib/lexxy/engine.rb`, the `lexxy.sanitization` initializer:

```ruby
initializer "lexxy.sanitization" do |app|
  ActiveSupport.on_load(:action_text_content) do
    default_allowed_tags = Class.new.include(ActionText::ContentHelper).new.sanitizer_allowed_tags
    ActionText::ContentHelper.allowed_tags = default_allowed_tags + %w[ video audio source embed table tbody tr th td ]

    default_allowed_attributes = Class.new.include(ActionText::ContentHelper).new.sanitizer_allowed_attributes
    ActionText::ContentHelper.allowed_attributes = default_allowed_attributes + %w[ controls poster data-language style value ]
    ...
  end
end
```

Rails 8.1 changed `ActionText::ContentHelper#sanitizer_allowed_tags` and `#sanitizer_allowed_attributes` from "return the default array" to a "configured?" probe that returns `true`/`false`. So `default_allowed_tags + %w[…]` calls `true + Array` and raises. The exception propagates out of the `on_load(:action_text_content)` hook and silently kills every subsequent ActionText load callback in the boot chain.

## How to reproduce

```bash
git clone https://github.com/basecamp/lexxy.git
cd lexxy/test/dummy
bundle install
rm -rf tmp/cache
bin/rails server
# Hit any URL → 500
```

Note: bootsnap can mask this on long-running dev machines (the load-hook outcome gets cached). `rm -rf tmp/cache` is required to reproduce reliably.

## Why Lexxy's CI doesn't catch it

PR [#778](https://github.com/basecamp/lexxy/pull/778) (merged 2026-04-07) added a CI matrix that runs `USE_RAILS_WITHOUT_ACTION_TEXT_ADAPTER=true` against Rails 8.1 specifically — but the bug still ships, so the test paths in that leg don't actually load `ActionText::Content` in a way that triggers the swallowed exception. Worth mentioning if/when filing the PR.

## Proposed fix

Two locations in the same initializer, ~4 lines total. Replace the probe with the actual sanitizer's default lists, which is what `sanitizer_allowed_tags` used to return:

```ruby
initializer "lexxy.sanitization" do |app|
  ActiveSupport.on_load(:action_text_content) do
    base_sanitizer = defined?(Rails::HTML5::SafeListSanitizer) ? Rails::HTML5::SafeListSanitizer : Rails::HTML::SafeListSanitizer

    default_allowed_tags = base_sanitizer.allowed_tags.to_a
    ActionText::ContentHelper.allowed_tags = default_allowed_tags + %w[ video audio source embed table tbody tr th td ]

    default_allowed_attributes = base_sanitizer.allowed_attributes.to_a
    ActionText::ContentHelper.allowed_attributes = default_allowed_attributes + %w[ controls poster data-language style value ]

    Loofah::HTML5::SafeList::ALLOWED_CSS_FUNCTIONS << "var"
  end
end
```

Works on Rails 8.0, 8.1, 8.2+. Both Rails versions expose `Rails::HTML::SafeListSanitizer.allowed_tags` returning the same default Loofah list that `sanitizer_allowed_tags` used to.

## When ready to upstream

1. Fork `basecamp/lexxy` → `JeromeSadou/lexxy`.
2. Branch `fix/rails-8-1-sanitizer-allowed-tags`.
3. Apply the 4-line patch above.
4. PR body needs:
   - Repro steps (above).
   - Mention the bootsnap masking effect.
   - Note the CI gap from #778.
   - Statement of compatibility (8.0 / 8.1 / 8.2+).
5. Probably worth opening an issue first for a community gem — Basecamp accepts drive-by PRs but a quick issue lets a maintainer triage.

## After the upstream fix lands

1. Bump `lexxy` in `Gemfile`.
2. Delete `config/initializers/lexxy_rails_8_1_compat.rb`.
3. Delete this file.
