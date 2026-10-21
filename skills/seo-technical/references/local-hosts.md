## Auditing a Local or Private Host

`url_safety` refuses loopback and private addresses by default, so `http://localhost:3000` and a staging host on Tailscale fail with "Blocked hostname" or "Blocked IP literal". That default is deliberate: these scripts follow URLs found on the pages they crawl.

To audit a pre-deployment host, the operator names it in `CLAUDE_SEO_LOCAL_TARGETS`, a comma-separated list of `host` or `host:port` entries:

```bash
CLAUDE_SEO_LOCAL_TARGETS="localhost:3000,127.0.0.1:8080,100.101.102.103" \
  "$HOME/.claude/skills/seo/scripts/claude-seo" run fetch_page.py http://localhost:3000/
```

What it does and does not cover:

| Behaviour | Allowlisted host |
|-----------|------------------|
| First, top-level URL over raw HTTP | Allowed |
| Redirect target reached from that URL | Refused |
| Subresource fetched by a rendered page | Refused |
| Playwright renders (`--render`, screenshots) | Refused; use the raw-HTTP path |
| A host not named in the variable | Refused |
| Cloud metadata endpoints, even when listed | Refused |

`host:port` matches that port only; a bare `host` matches any port. With the variable unset the policy is unchanged. Never suggest setting it for a host the user does not control.
