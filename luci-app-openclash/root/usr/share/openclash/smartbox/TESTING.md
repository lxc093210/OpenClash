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

The workflow is maintained on `feature/sing-box-smart-adapter`. GitHub may not
show a **Run workflow** button when a workflow exists only on a non-default
branch; a push that changes `luci-app-openclash/` on this branch starts the
build automatically. Do not switch to `master` to trigger or test this work.

```sh
opkg update
opkg install /tmp/luci-app-openclash_0.48.002_all.ipk
```

If an older `luci-app-openclash` of the same version is already installed,
use `opkg install --force-reinstall /tmp/luci-app-openclash_0.48.002_all.ipk`.
Check that `opkg` resolves all declared runtime dependencies. The IPK does not
bundle a Smart core binary.

The isolated VM smoke test can also be started from the `SmartBox isolated
OpenWrt VM smoke` workflow. Use its **Run workflow** action and enter the run
ID of a successful IPK build (for example, `41218321096`). The latest
successful build's artifact is available at
`https://github.com/lxc093210/OpenClash/actions/artifacts/13048178993`. The
workflow downloads that run's artifact and boots a disposable QEMU OpenWrt
instance; it does not connect to a physical router. Image preparation accepts
the verified image's ext4 rootfs directly and does not require loop partition
device creation.
If preparation or installation fails, the workflow publishes the failing
command's line number as an Actions annotation and uses SSH streaming instead
of SCP for control traffic; the VM downloads the IPK from a temporary
runner-local HTTP server over QEMU user networking. Feed, LuCI dependency,
and SmartBox IPK installation errors are emitted as Actions annotations.
Guest runtime assertions have their own failure line annotation.
The guest mode check uses BusyBox `ls -l` because the minimal image does not
ship `stat`.
The guest uses an explicit `smoke` provider section to avoid anonymous UCI
section differences in minimal images.
The two initial provider writes publish UCI stderr and state on failure.
The package build also sets `/etc/config/smartbox` to `0600` before creating
the IPK, so secrets are protected even if a package manager skips postinst.
This document is updated on the feature branch to trigger the isolated smoke
job after each package build.
The disposable VM replaces the generic image's `dnsmasq` package because the
LuCI dependency selects `dnsmasq-full`; the
smoke setup removes that disposable base package before installing LuCI.
The VM workflow uses a single-command Python decompressor to avoid shell
heredoc differences between runner images.
Reusable workflow calls download the artifact from the caller run; direct
manual runs use the supplied verified build run ID.
Decompression errors are surfaced as an Actions annotation.
The preparation step also verifies the gzip magic bytes before extraction.
The VM preparation edits a preseeded network UCI file when present; otherwise
it writes a minimal DHCP LAN configuration for QEMU user-mode networking.
It uses zlib stream decompression because the release archive contains a
trailing certificate metadata block after the gzip stream.

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
- VM failures in the pinned Smart core installation step include the final
  installer lines in a sanitized CI annotation, covering download, checksum,
  and archive extraction errors without exposing subscription or API secrets.
- The VM also expands the image root partition and ext4 filesystem after
  resizing the disk container; the pinned Smart binary is larger than the
  stock writable root filesystem.
- The filesystem check accepts e2fsck's documented exit code 1 when repairs
  were applied, while still failing on uncorrected errors.
- The package RPCD ACL grants the LuCI role read/write access to both the
  original `openclash` UCI config and the SmartBox `smartbox` config, so the
  experimental page can persist its own settings without broad UCI access.
