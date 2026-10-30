# SmartBox experimental installation and rollback

Use an isolated OpenWrt 24.10.x or matching ImmortalWrt x86_64 test VM. This
branch has only been packaged with the OpenWrt 24.10.3 x86_64 SDK. Router-wide
DNS, firewall, TUN and policy handover are not implemented. Do not install this
experimental package on a production router.

## Before installation

The package retains the name `luci-app-openclash`. Keep the previous IPK so it
can be reinstalled. Back up `/etc/config/openclash`, `/etc/openclash`, and any
other locally modified OpenClash files outside the router before upgrading.
The package declares `/etc/config/openclash` and `/etc/config/smartbox` as
conffiles and does not remove OpenClash's config directory during uninstall.

Download the IPK from the successful `SmartBox experimental IPK build` GitHub
Actions run. Extract the artifact ZIP and transfer
`x86_64/base/luci-app-openclash_0.48.002_all.ipk` to the test VM. Install or
upgrade with:

```sh
opkg update
opkg install /tmp/luci-app-openclash_0.48.002_all.ipk
```

If an older `luci-app-openclash` of the same version is already installed,
use `opkg install --force-reinstall /tmp/luci-app-openclash_0.48.002_all.ipk`.
Check that `opkg` resolves all declared runtime dependencies. The IPK does not
bundle a Smart core binary.

## Localhost validation

1. Open LuCI > Services > SmartBox (Experimental). Keep the independent
   service disabled while configuring it.
2. Click **Install pinned Smart core**, then **Generate API secret**. Use a
   disposable HTTPS subscription for this test, give it a unique name, enable
   that provider, and save.
3. Confirm ports 2088 and 19090 are free and distinct. Enable the independent
   service, save, then click **Start local test**.
4. Check LuCI > Services > SmartBox > Smart Ranking for runtime status, current
   node, ranking and recent logs. Ranking needs actual proxied connections to
   accumulate useful data.
5. From the test VM only, send traffic through `127.0.0.1:2088` and verify the
   response. Keep OpenClash's existing service and LAN routing unchanged.
6. Stop SmartBox. Compare DNS, firewall and routes with the pretest state.

Do not publish `/etc/config/smartbox`, generated JSON, subscription URLs, API
secrets or unredacted core logs.

## Recovery

For a failed Smart core update, stop SmartBox in LuCI and click **Rollback
Smart core**. For a failed package upgrade, run `/etc/init.d/smartbox stop` and
reinstall the previous OpenClash IPK with `opkg install --force-reinstall`.
Restore the backed-up OpenClash config and directory if needed, then restart
OpenClash. The experimental Smart service does not alter DNS, firewall or
routes, so stopping it should restore the pretest network state immediately.

## Remaining limits

- The package build and Smart configuration syntax are checked in GitHub
  Actions; installation and proxy traffic still need an isolated router VM.
- UCI changes do not automatically restart procd. Use the LuCI Stop and Start
  buttons after changing SmartBox settings.
- No automatic Mihomo/Smart switch, global interception, Fake-IP or device
  policy handover exists yet.
- The Smart core installer currently targets x86_64 and aarch64 releases only.
