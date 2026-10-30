# OpenClash SmartBox — dual-core adaptation

Status: **experimental / development only**. The original `master` is untouched.

## Goal

Keep the OpenClash LuCI interface and Mihomo implementation operational while adding an
**opt-in** sing-box Smart engine. There must be no DNS, firewall, routing, or TUN changes
until the standalone adapter has passed integration testing.

## Compatibility contract

| Surface | Mihomo / OpenClash | sing-box Smart |
|---|---|---|
| Runtime config | Clash YAML | sing-box JSON |
| Subscriptions | proxy-providers | Smart branch `providers` |
| Smart group | Mihomo-specific smart strategy | `outbounds.type=smart` |
| Control API | Clash REST API | Clash-compatible REST API (subset + Smart extensions) |
| Transparent proxy | Existing OpenClash firewall scripts | Separate, future TUN/redir adapter |
| DNS | Existing OpenClash DNS implementation | sing-box DNS configuration, must not mix |
| LuCI | Existing OpenClash app | New opt-in screens and status provider |

Never point the existing Mihomo process directly at sing-box JSON, and never use an
OpenClash-generated YAML file as sing-box Smart configuration.

## Milestones

- **M0 (this commit):** Non-mutating compatibility preflight and architecture guidance.
- **M1:** Explicit enable/disable, provider management, JSON generator and `sing-box check`.
- **M2:** Independent local mixed-port smoke tests and Smart API adapter; no LAN intercept.
- **M3:** LuCI UI for engine selection, subscription/status, Smart ranking, update/rollback.
- **M4:** Exclusive lifecycle handover: stop current stack, snapshot, validate, start,
  health-check, and automatically restore Mihomo if sing-box fails.
- **M5:** DNS/TUN/firewall and per-device policy integration with iptables/nftables version
  detection and rollback; target ImmortalWrt x86_64 first.
- **M6:** OpenWrt SDK packaging, GitHub Actions build matrix and installable artifacts.

## Security rules

- Never log provider URLs, tokens, raw config, or API secrets.
- Store confidential files mode 0600; directories 0700.
- Bind test inbounds/API to localhost by default.
- Always validate downloaded release checksums; pin a known version and maintain rollback.
- Fail closed on failed configuration validation.
- Do not run both systems' global DNS hijacking or packet interception simultaneously.
- Never modify OpenClash configuration or startup services in the preflight step.

## Upstream

- https://github.com/vernesong/OpenClash
- https://github.com/MiChongs/sing-box
- https://michongs.github.io/sing-box/zh/quick-start/

Fork licensing and redistribution must preserve the original licenses and notices.
