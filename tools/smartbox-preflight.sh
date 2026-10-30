#!/bin/sh
# OpenClash SmartBox read-only diagnostic, first development milestone.
# No service, UCI, firewall, or DNS mutation.
set -u

printf '%s\n' '=== OpenClash SmartBox preflight (read only) ==='
printf 'Architecture: '
uname -m
printf 'OpenWrt release: '
if [ -r /etc/openwrt_release ]; then
  sed -n 's/^DISTRIB_RELEASE=//p' /etc/openwrt_release | head -n 1
else
  echo 'unknown'
fi
printf 'Overlay free space: '
df -h /overlay 2>/dev/null | tail -n 1 || true

printf '\n%s\n' '--- Binary candidates ---'
for bin in /usr/bin/sing-box /usr/local/bin/sing-box-smart /usr/bin/sing-box-smart /etc/openclash/core/clash_meta; do
  if [ -x "$bin" ]; then
    printf 'present: %s\n' "$bin"
  else
    printf 'absent:  %s\n' "$bin"
  fi
done

printf '\n%s\n' '--- Installed OpenClash service ---'
if [ -f /etc/init.d/openclash ]; then
  echo 'OpenClash init script present'
else
  echo 'OpenClash init script absent'
fi

printf '\n%s\n' '--- Runtime listeners (metadata only) ---'
if command -v netstat >/dev/null 2>&1; then
  netstat -lnt 2>/dev/null | grep -E ':(53|7890|7891|9090|19090)[[:space:]]' || true
else
  echo 'netstat not installed'
fi
printf '\nNo changes were made.\n'
