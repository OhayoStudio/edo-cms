# Security policy

## Supported versions

Only the `main` branch receives fixes. There are no tagged releases; brand forks track `main` and cherry-pick as needed.

## Reporting a vulnerability

Please do **not** open a public issue for security disclosures.

Email **jerome@ohayostudio.com** with:

- A description of the issue
- Steps to reproduce (or a minimal proof-of-concept)
- Affected version / commit SHA, if known
- Your name / handle for credit (optional)

Expect a first response within **7 days**. We'll work with you on a coordinated disclosure timeline — typically 30–90 days depending on severity.

## What's in scope

- Authentication bypass, session fixation, privilege escalation in the admin namespace
- SQL injection, XSS, CSRF in any controller / view
- Active Storage / Lexxy upload handling (unrestricted file types, path traversal, etc.)
- Authentication concern (`app/controllers/concerns/authentication.rb`) and session handling
- Deserialization, mass assignment in admin params
- Dependency vulnerabilities not yet flagged by Dependabot or Brakeman

## What's out of scope

- Anything in a brand fork's own customizations — report to that fork's maintainers.
- Issues that require admin credentials to exploit (the admin namespace is trusted by design).
- Reports based on automated scanner output without a working exploit.
- Configuration issues in a specific deployment (your `.env`, your Kamal secrets, your GCS bucket policy, your Umami instance — those are yours).

## Hall of fame

If you report a real issue, we'll list you here (with permission).

_No reports yet._
