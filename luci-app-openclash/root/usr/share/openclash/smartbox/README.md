# SmartBox experimental adapter

This adapter is intentionally opt-in. The default sidecar mode is localhost
only; an explicitly selected global mode uses sing-box's documented Linux TUN
auto-route and takes over only after stopping OpenClash. Auto-redirect is
optional because it requires kernel nfqueue support. The
Smart binary is supplied separately; no untrusted binary is bundled here.

The current implementation includes the LuCI route, HTTPS provider validation,
secret protection, pinned core installation and rollback, runtime start/stop,
post-start local health checking with automatic stop-on-failure, watchdog recovery,
Smart API ranking, package checks and isolated VM smoke-test workflow. Global
mode is experimental and must be tested in an isolated router before use on a
production router. It accepts explicit SmartBox device IPv4 CIDR and
domain-suffix policies from LuCI. Existing OpenClash YAML rules and its
device-policy database are not imported automatically; the explicit importer
can copy supported entries while leaving the source YAML unchanged.
Smart Fake-IP is also available for global mode. It uses sing-box's current
Fake-IP DNS server for A and AAAA queries and is disabled by default.
The settings page also has an explicit OpenClash rule importer for common
DOMAIN, DOMAIN-SUFFIX, DOMAIN-KEYWORD, IP-CIDR and SRC-IP-CIDR entries. It
never rewrites the source YAML and reports how many unsupported entries were
skipped.

The ranking page reports both the process state and a localhost API health check.
The start control waits for that health check and stops the sidecar if it does not
become healthy, so a failed Smart start does not leave a respawning process behind.
It can request an immediate recompute, clear a manual pin, or
pin one reported node. These actions are sent only to the localhost Smart API,
use the root-only API header file, and reject group names and node values that
cannot be safely represented in the request.

Each HTTPS subscription can optionally provide a bounded `User-Agent` value
(default `clash`) for providers that require a Clash-compatible client header.
