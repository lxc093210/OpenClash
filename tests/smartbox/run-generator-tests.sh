#!/usr/bin/env bash
# Exercise the real generator against mocked UCI and a mock sing-box validator.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/state"
cp "$ROOT/luci-app-openclash/root/usr/libexec/smartbox-generate" "$TMP/generate"
chmod +x "$TMP/generate"
# Only the test copy uses a temporary configuration directory.
sed -i "s#/etc/sing-box-smart#$TMP/state#g" "$TMP/generate"
cat > "$TMP/bin/uci" <<'SH'
#!/bin/sh
case "$*" in
  '-q get smartbox.main.binary') printf '%s\n' "$MOCK_CORE_BIN" ;;
  *) exit 1 ;;
esac
SH
cat > "$TMP/bin/mock-core" <<'SH'
#!/bin/sh
[ "$1" = check ] && [ "$2" = -c ] || exit 1
python3 - "$3" <<'PY'
import json,sys
data=json.load(open(sys.argv[1]))
assert data['inbounds'][0]['listen']=='127.0.0.1'
assert data['inbounds'][0]['listen_port']==2088
assert data['providers'][0]['type']=='remote'
assert data['providers'][0]['tag']=='airport_test'
assert data['outbounds'][0]['type']=='smart'
assert data['outbounds'][0]['providers']==['airport_test']
assert data['experimental']['clash_api']['external_controller']=='127.0.0.1:19090'
assert len(data['experimental']['clash_api']['secret']) >= 24
PY
SH
chmod +x "$TMP/bin/"*
export MOCK_CORE_BIN="$TMP/bin/mock-core"
export PATH="$TMP/bin:$PATH"
export LUA_PATH="$ROOT/tests/smartbox/mocks/?.lua;$ROOT/tests/smartbox/mocks/?/init.lua;;"
echo '[1/5] valid provider produces validated JSON'
"$TMP/generate" >/dev/null
test -s "$TMP/state/config.json"
echo '[2/5] insecure HTTP subscriptions rejected'
if MOCK_PROVIDER_URL='http://example.test/unsafe' "$TMP/generate" >/dev/null 2>&1; then
  echo "ERROR: HTTP URL was accepted"; exit 1
fi
echo '[3/5] short API secret rejected'
if MOCK_SECRET='abc' "$TMP/generate" >/dev/null 2>&1; then
  echo "ERROR: short API secret was accepted"; exit 1
fi
echo '[4/5] duplicate providers rejected'
if MOCK_DUPLICATE=1 "$TMP/generate" >/dev/null 2>&1; then
  echo "ERROR: duplicate provider was accepted"; exit 1
fi
echo '[5/5] invalid update interval rejected'
if MOCK_INTERVAL='1m' "$TMP/generate" >/dev/null 2>&1; then
  echo "ERROR: invalid interval was accepted"; exit 1
fi
test ! -e "$TMP/state/config.candidate.json"
echo 'SmartBox generator smoke tests passed'
