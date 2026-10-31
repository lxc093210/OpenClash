# SmartBox experimental adapter

This adapter is intentionally opt-in and localhost-only. It is not a fully
functioning OpenClash dual-core drop-in: the LuCI page starts an isolated
sing-box Smart sidecar and does not take over OpenClash DNS, firewall, TUN,
routes or LAN policies. The Smart binary is supplied separately; no untrusted
binary is bundled here.

The current implementation includes the LuCI route, HTTPS provider validation,
secret protection, pinned core installation and rollback, runtime start/stop,
Smart API ranking, package checks and isolated VM smoke-test workflow. Global
Mihomo/Smart handover remains deliberately disabled until it has an atomic
firewall/DNS transition and recovery test. Do not install on a production
router.
