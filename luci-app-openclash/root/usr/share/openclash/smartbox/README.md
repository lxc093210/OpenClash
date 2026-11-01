# SmartBox experimental adapter

This adapter is intentionally opt-in and localhost-only. It is not a fully
functioning OpenClash dual-core drop-in: the LuCI page starts an isolated
sing-box Smart sidecar and does not take over OpenClash DNS, firewall, TUN,
routes or LAN policies. The Smart binary is supplied separately; no untrusted
binary is bundled here.

The current implementation includes the LuCI route, HTTPS provider validation,
secret protection, pinned core installation and rollback, runtime start/stop,
post-start local health checking with automatic stop-on-failure, Smart API ranking,
package checks and isolated VM smoke-test workflow. Global
Mihomo/Smart handover remains deliberately disabled until it has an atomic
firewall/DNS transition and recovery test. Do not install on a production
router.

The ranking page reports both the process state and a localhost API health check.
The start control waits for that health check and stops the sidecar if it does not
become healthy, so a failed Smart start does not leave a respawning process behind.
It can request an immediate recompute, clear a manual pin, or
pin one reported node. These actions are sent only to the localhost Smart API,
use the root-only API header file, and reject group names and node values that
cannot be safely represented in the request.

Each HTTPS subscription can optionally provide a bounded `User-Agent` value
(default `clash`) for providers that require a Clash-compatible client header.
