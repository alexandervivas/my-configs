# Secure Setup for OpenRouter in OpenCode

## Environment Key

Store the key in `.envrc`:

```bash
export OPENROUTER_API_KEY='sk-or-...'
```

Load it with your shell workflow (for example `direnv allow`).

## Non-Commit Rules

- Never commit `.envrc`.
- Never paste keys into tracked config files.
- Prefer `{env:OPENROUTER_API_KEY}` references in `opencode.json`.

## Recommended Hardening

- Rotate keys immediately if exposed.
- Set budget limits/alerts in OpenRouter.
- Use per-project keys when possible.
- Restrict premium-tier use via policy thresholds.
