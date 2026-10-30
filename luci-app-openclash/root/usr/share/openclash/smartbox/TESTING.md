# SmartBox initial integration: limitations and tests

**DO NOT DEPLOY ON A PRODUCTION ROUTER YET.**

This is a development prototype with a LuCI entry, UCI definitions, a Lua JSON
generator, and an isolated procd service. It is not a complete dual-core OpenClash
implementation. The package build and file permissions have not been validated.

## Manual test sequence (test VM only)

1. Ensure OpenClash remains available as a fallback. Back up all config.
2. Install the required sing-box Smart binary separately.
3. Confirm `/etc/config/smartbox` exists and the LuCI SmartBox menu appears.
4. Add a disposable HTTPS provider and enable it in UCI.
5. Keep OpenClash enabled: SmartBox now supports localhost-only sidecar mode.
6. Confirm TCP ports 2088 and 19090 are available locally.
7. Run `/usr/libexec/smartbox-generate` and inspect the generated JSON without
   sharing private provider URLs.
8. Run `sing-box-smart check -c /etc/sing-box-smart/config.json`.
9. Run `/etc/init.d/smartbox start`, check that localhost:2088 is listening.
10. Stop SmartBox; ensure no DNS, iptables, nftables or routes changed.

## Known blockers

- OpenClash package's install scripts and file permissions must be reviewed.
- Actual sing-box Smart version compatibility must be tested.
- UCI changes alone do not trigger procd restart.
- The LuCI ranking view reads real Smart API data; its UX requires router testing.
- API secrets and provider URLs reside in the UCI file; the package and token utility set mode 0600, but permissions must be checked after upgrades.
- The sidecar may run beside OpenClash because it binds loopback only. This branch has **no automatic handover** and **no global interception**.
- Provider URLs must be kept secret. Do not upload real subscriptions to issues.
