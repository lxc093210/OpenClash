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
import json,os,sys
data=json.load(open(sys.argv[1]))
if data['inbounds'][0].get('type') == 'tun':
    tun=data['inbounds'][0]
    assert tun['interface_name']=='smarttun', tun
    assert tun['auto_route'] is True, tun
    assert tun['auto_redirect'] is (os.environ.get('MOCK_AUTO_REDIRECT') == '1'), tun
    assert tun['dns_mode']=='hijack', tun
    assert 'sniff' not in tun and 'sniff_override_destination' not in tun, tun
    assert data['route']['auto_detect_interface'] is True, data['route']
    rules=data['route']['rules']
    assert rules[0]=={'inbound':'tun-in','action':'resolve','strategy':'prefer_ipv4'}, rules
    assert rules[1]=={'inbound':'tun-in','action':'sniff'}, rules
    assert rules[2]=={'inbound':'tun-in','protocol':'dns','action':'hijack-dns'}, rules
    assert data['dns']['servers'][0]['type']=='https', data['dns']
    assert 'detour' not in data['dns']['servers'][0], data['dns']
    if os.environ.get('MOCK_FAKEIP') == '1':
        assert data['dns']['servers'][1] == {
            'type':'fakeip','tag':'smart-fakeip',
            'inet4_range':'198.18.0.0/15','inet6_range':'2001:2::/48'}
        assert data['dns']['rules'] == [{'query_type':['A','AAAA'], 'server':'smart-fakeip'}]
else:
    assert data['inbounds'][0]['listen']=='127.0.0.1', data['inbounds'][0]
    assert data['inbounds'][0]['listen_port']==2088, data['inbounds'][0]
assert data['providers'][0]['type']=='remote'
assert data['providers'][0]['tag']=='airport_test'
assert data['providers'][0]['http_client']=='fetch-airport_test'
assert 'user_agent' not in data['providers'][0]
assert data['http_clients'][1]['headers']['User-Agent']=='clash'
assert all('detour' not in client for client in data['http_clients']), data['http_clients']
assert data['outbounds'][0]['type']=='smart'
assert data['outbounds'][0]['providers']==['airport_test']
assert data['outbounds'][0]['use_lightgbm'] is True
assert data['outbounds'][0]['collect_data'] is True
assert data['outbounds'][0]['sample_rate']==0.25
assert data['outbounds'][0]['expected_status']=='204'
assert data['outbounds'][0]['prefer_asn'] is False
assert data['outbounds'][0]['tolerance']==0
assert data['outbounds'][0]['exclude']=='(?i)剩余|到期|官网'
assert data['experimental']['clash_api']['external_controller']=='127.0.0.1:19090'
assert len(data['experimental']['clash_api']['secret']) >= 24
if os.environ.get('MOCK_DEVICE_POLICY') == '1':
    assert {'inbound':'tun-in','source_ip_cidr':'192.168.1.100/32',
            'action':'route','outbound':'direct'} in data['route']['rules'], data['route']['rules']
if os.environ.get('MOCK_DOMAIN_POLICY') == '1':
    assert {'inbound':'tun-in','domain_suffix':'example.com',
            'action':'reject'} in data['route']['rules'], data['route']['rules']
if os.environ.get('MOCK_IP_POLICY') == '1':
    assert {'inbound':'tun-in','ip_cidr':'203.0.113.0/24',
            'action':'route','outbound':'direct'} in data['route']['rules'], data['route']['rules']
PY
SH
chmod +x "$TMP/bin/"*
export MOCK_CORE_BIN="$TMP/bin/mock-core"
export PATH="$TMP/bin:$PATH"
export LUA_PATH="$ROOT/tests/smartbox/mocks/?.lua;$ROOT/tests/smartbox/mocks/?/init.lua;;"
echo '[1/11] valid provider produces validated JSON'
"$TMP/generate" >/dev/null
test -s "$TMP/state/config.json"
echo '[2/11] global mode produces official TUN and DNS fields'
MOCK_MODE=global "$TMP/generate" >/dev/null
MOCK_MODE=global MOCK_AUTO_REDIRECT=1 "$TMP/generate" >/dev/null
echo '[3/11] global device and domain policies produce route actions'
MOCK_MODE=global MOCK_DEVICE_POLICY=1 MOCK_DOMAIN_POLICY=1 MOCK_IP_POLICY=1 "$TMP/generate" >/dev/null
echo '[4/11] global Fake-IP produces current DNS server and rule fields'
MOCK_MODE=global MOCK_FAKEIP=1 "$TMP/generate" >/dev/null
echo '[5/11] invalid Smart policies rejected'
if MOCK_MODE=global MOCK_DEVICE_POLICY=1 MOCK_DOMAIN_POLICY=1 MOCK_BAD_POLICY=1 "$TMP/generate" >/dev/null 2>&1; then
  echo "ERROR: invalid Smart policy was accepted"; exit 1
fi
echo '[6/11] insecure HTTP subscriptions rejected'
if MOCK_PROVIDER_URL='http://example.test/unsafe' "$TMP/generate" >/dev/null 2>&1; then
  echo "ERROR: HTTP URL was accepted"; exit 1
fi
echo '[7/11] short API secret rejected'
if MOCK_SECRET='abc' "$TMP/generate" >/dev/null 2>&1; then
  echo "ERROR: short API secret was accepted"; exit 1
fi
echo '[8/11] duplicate providers rejected'
if MOCK_DUPLICATE=1 "$TMP/generate" >/dev/null 2>&1; then
  echo "ERROR: duplicate provider was accepted"; exit 1
fi
echo '[9/11] invalid update interval rejected'
if MOCK_INTERVAL='1m' "$TMP/generate" >/dev/null 2>&1; then
  echo "ERROR: invalid interval was accepted"; exit 1
fi
echo '[10/11] invalid Smart probe status rejected'
if MOCK_EXPECTED_STATUS='not-a-status' "$TMP/generate" >/dev/null 2>&1; then
  echo "ERROR: invalid probe status was accepted"; exit 1
fi
echo '[11/11] invalid Smart sample rate rejected'
if MOCK_SAMPLE_RATE='0' "$TMP/generate" >/dev/null 2>&1; then
  echo "ERROR: invalid sample rate was accepted"; exit 1
fi
test ! -e "$TMP/state/config.candidate.json"
echo 'SmartBox generator smoke tests passed'
