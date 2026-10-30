# SmartBox experimental adapter

This adapter is intentionally opt-in and localhost-only. It must not be described
as a fully functioning OpenClash dual-core drop-in. To enable the LuCI page,
register `form("openclash/smartbox")` under the OpenClash controller. The Smart
binary is supplied separately; no untrusted binary is bundled here.

Development checklist: add page route, secure secrets and URLs, verify generator
against actual installed sing-box Smart version, package permissions, runtime
start/stop actions, automated tests and rollback. Do not install on a production
router until the checklist is completed.
