local m = Map("smartbox", translate("sing-box Smart (experimental)"),
 translate("Sidecar mode is localhost-only and can run alongside Mihomo. Global TUN mode is experimental: it stops OpenClash before takeover and restores it when stopped or when startup fails. Test global mode in an isolated router first. Provider URLs are confidential. Save changes before starting the service."))

function m.on_after_commit(self)
  os.execute("chmod 0600 /etc/config/smartbox")
end

local s = m:section(NamedSection, "main", "smartbox", translate("Runtime"))
s.addremove = false
local enabled = s:option(Flag, "enabled", translate("Enable independent service"))
enabled.default = "0"
local mode = s:option(ListValue, "mode", translate("Traffic mode"))
mode:value("sidecar", translate("Localhost sidecar (safe default)"))
mode:value("global", translate("Global TUN proxy (experimental)"))
mode.default = "sidecar"
mode.description = translate("Global mode stops OpenClash before takeover and restores it when SmartBox stops or startup fails. Test in an isolated router first.")
local binary = s:option(Value, "binary", translate("Smart binary path"))
binary.default = "/usr/bin/sing-box-smart"
function binary.validate(self, value)
 if value and value:match("^/[A-Za-z0-9_./-]+$") then return value end
 return nil, translate("Use an absolute executable path without spaces or shell characters")
end
local port = s:option(Value, "listen_port", translate("Local mixed proxy port"))
port.datatype = "port"
port.default = "2088"
local tun_interface = s:option(Value, "tun_interface", translate("Smart TUN interface"))
tun_interface.default = "smarttun"
tun_interface:depends("mode", "global")
function tun_interface.validate(self, value)
 if value and #value <= 15 and value:match("^[A-Za-z0-9_.-]+$") then return value end
 return nil, translate("Use a Linux interface name up to 15 characters")
end
local tun_address = s:option(Value, "tun_address", translate("Smart TUN address"))
tun_address.default = "172.19.0.1/30"
tun_address:depends("mode", "global")
function tun_address.validate(self, value)
 if value and value:match("^[0-9%.]+/[0-9]+$") then return value end
 return nil, translate("Use an IPv4 CIDR address, for example 172.19.0.1/30")
end
local auto_redirect = s:option(Flag, "tun_auto_redirect", translate("TUN auto redirect"))
auto_redirect.default = "0"
auto_redirect:depends("mode", "global")
auto_redirect.description = translate("Requires kernel nfqueue support; startup rolls back if the router cannot enable it")
local fakeip = s:option(Flag, "fakeip_enabled", translate("Smart Fake-IP"))
fakeip.default = "0"
fakeip:depends("mode", "global")
fakeip.description = translate("Return sing-box Fake-IP addresses for A/AAAA queries; use the reserved ranges below")
local fakeip4 = s:option(Value, "fakeip_ipv4_range", translate("Fake-IP IPv4 range"))
fakeip4.default = "198.18.0.0/15"
fakeip4:depends({mode="global", fakeip_enabled="1"})
function fakeip4.validate(self, value)
 local a,b,c,d,prefix = value and value:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)/(%d+)$")
 if a and tonumber(a) <= 255 and tonumber(b) <= 255 and tonumber(c) <= 255 and
   tonumber(d) <= 255 and tonumber(prefix) <= 32 then return value end
 return nil, translate("Use a valid IPv4 CIDR, for example 198.18.0.0/15")
end
local fakeip6 = s:option(Value, "fakeip_ipv6_range", translate("Fake-IP IPv6 range"))
fakeip6.default = "2001:2::/48"
fakeip6:depends({mode="global", fakeip_enabled="1"})
function fakeip6.validate(self, value)
 local prefix = value and value:match("^[0-9A-Fa-f:]+/(%d+)$")
 if prefix and tonumber(prefix) <= 128 then return value end
 return nil, translate("Use a valid IPv6 CIDR, for example 2001:2::/48")
end
local controller = s:option(Value, "controller_port", translate("Local controller port"))
controller.datatype = "port"
controller.default = "19090"
local probe = s:option(Value, "probe_url", translate("Smart probe URL"))
probe.default = "https://www.gstatic.com/generate_204"
function probe.validate(self, value)
 if value and value:match("^https://[^%c%s]+$") then return value end
 return nil, translate("Use an HTTPS probe URL")
end
local expected = s:option(Value, "expected_status", translate("Expected probe status"))
expected.default = "204"
function expected.validate(self, value)
 if value and #value <= 32 and value:match("^[%d*/%-]+$") then return value end
 return nil, translate("Use a status code, range, or slash-separated status codes")
end
local asn = s:option(Flag, "prefer_asn", translate("Prefer ASN grouping"))
asn.default = "0"
asn.description = translate("Reuse quality data for destinations on the same network")
local tolerance = s:option(Value, "tolerance", translate("Delay tolerance (ms)"))
tolerance.datatype = "uinteger"
tolerance.default = "0"
local sample = s:option(Value, "sample_rate", translate("Learning sample rate"))
sample.default = "0.25"
function sample.validate(self, value)
 local n = tonumber(value)
 if n and n >= 0.01 and n <= 1 then return value end
 return nil, translate("Use a value between 0.01 and 1")
end
local collect = s:option(Flag, "collect_data", translate("Collect Smart training data"))
collect.default = "1"
local lightgbm = s:option(Flag, "use_lightgbm", translate("Use LightGBM quality model"))
lightgbm.default = "1"
local exclude = s:option(Value, "exclude_pattern", translate("Exclude node pattern"))
exclude.default = "(?i)剩余|到期|官网|traffic|expire"
function exclude.validate(self, value)
 if value and #value <= 512 and not value:find("[%c]") then return value end
 return nil, translate("Use at most 512 characters without control characters")
end
local policy = s:option(Value, "policy_priority", translate("Node priority rules"))
policy.default = ""
function policy.validate(self, value)
 if value and #value <= 512 and not value:find("[%c]") then return value end
 return nil, translate("Use at most 512 characters without control characters")
end
local secret = s:option(Value, "api_secret", translate("API secret"))
secret.password = true
secret.rmempty = true
secret.description = translate("Required to start: a random token with at least 24 characters. You can generate it below.")
function secret.validate(self, value)
  if value == nil or value == "" then return value end
  if #value >= 24 and value:match("^[%w_-]+$") then return value end
  return nil, translate("Use at least 24 letters, numbers, underscore or hyphen characters")
end
local keygen = s:option(Button, "_generate_secret", translate("Generate API secret"))
keygen.inputstyle = "apply"
function keygen.write(self, section)
  local rc = os.execute("/usr/libexec/smartbox-secret-init >/dev/null 2>&1")
  if rc == 0 then
    require("luci.http").redirect(require("luci.dispatcher").build_url("admin", "services", "smartbox"))
  else
    self.description = translate("Generation failed; check system log.")
  end
end

local p = m:section(TypedSection, "provider", translate("HTTPS subscriptions"))
p.anonymous = true
p.addremove = true
local on = p:option(Flag, "enabled", translate("Enabled"))
on.default = "0"
local name = p:option(Value, "name", translate("Unique name"))
name.datatype = "uciname"
name.rmempty = false
function name.validate(self, value)
 if value and value:match("^[%w_-]+$") then return value end
 return nil, translate("Use only letters, numbers, underscore or hyphen characters")
end
local url = p:option(Value, "url", translate("Subscription URL"))
url.password = true
url.rmempty = false
function url.validate(self, value, section)
 if value and value:match("^https://[^%c%s]+$") then return value end
 return nil, translate("An HTTPS URL is required")
end
local user_agent = p:option(Value, "user_agent", translate("Subscription User-Agent"))
user_agent.default = "clash"
user_agent.rmempty = true
user_agent.description = translate("Optional header used by providers that require a Clash-compatible client identifier")
function user_agent.validate(self, value)
 if value == nil or value == "" then return value end
 if #value <= 200 and not value:find("[%c]") then return value end
 return nil, translate("Use at most 200 characters without control characters")
end
local interval = p:option(Value, "update_interval", translate("Refresh interval"))
interval.default = "12h"
interval.rmempty = false
function interval.validate(self, value)
 local count, unit = value and value:match("^([1-9]%d*)([hm])$")
 if count and (unit == "h" or tonumber(count) >= 60) then return value end
 return nil, translate("Use an interval of at least 1 hour, for example 1h or 12h")
end

local device = m:section(TypedSection, "device_policy", translate("Smart device policies"),
 translate("Global TUN mode only. The first matching device policy wins; use a stable DHCP address for each device."))
device.anonymous = true
device.addremove = true
device.sortable = true
local device_enabled = device:option(Flag, "enabled", translate("Enabled"))
device_enabled.default = "0"
local source_ip = device:option(Value, "source_ip_cidr", translate("Device IPv4 CIDR"))
source_ip.rmempty = false
source_ip.placeholder = "192.168.1.100/32"
function source_ip.validate(self, value)
 local a,b,c,d,prefix = value and value:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)/(%d+)$")
 if a and tonumber(a) <= 255 and tonumber(b) <= 255 and
   tonumber(c) <= 255 and tonumber(d) <= 255 and tonumber(prefix) <= 32 then return value end
 return nil, translate("Use an IPv4 CIDR such as 192.168.1.100/32")
end
local device_target = device:option(ListValue, "target", translate("Route"))
device_target:value("auto", translate("Smart selection"))
device_target:value("direct", translate("Direct"))
device_target:value("reject", translate("Reject"))
device_target.default = "auto"

local domain = m:section(TypedSection, "domain_policy", translate("Smart domain policies"),
 translate("Global TUN mode only. Device policies take precedence over these suffix rules."))
domain.anonymous = true
domain.addremove = true
domain.sortable = true
local domain_enabled = domain:option(Flag, "enabled", translate("Enabled"))
domain_enabled.default = "0"
local suffix = domain:option(Value, "domain_suffix", translate("Domain suffix"))
suffix.rmempty = false
suffix.placeholder = "example.com"
function suffix.validate(self, value)
 value = value and value:lower()
 if value and #value <= 253 and value:match("^[a-z0-9][a-z0-9.%-]*[a-z0-9]$") and
   not value:find("%.%.") and not value:find("%.%-") and not value:find("%-%.") then return value end
 return nil, translate("Use an ASCII or punycode domain suffix such as example.com")
end
local domain_target = domain:option(ListValue, "target", translate("Route"))
domain_target:value("auto", translate("Smart selection"))
domain_target:value("direct", translate("Direct"))
domain_target:value("reject", translate("Reject"))
domain_target.default = "auto"

local controls = m:section(SimpleSection)
local core = controls:option(DummyValue, "_core", translate("Smart core"))
function core.cfgvalue(self, section)
  local uci = require("luci.model.uci").cursor()
  local util = require("luci.util")
  local bin = uci:get("smartbox", "main", "binary") or "/usr/bin/sing-box-smart"
  if not bin:match("^/[A-Za-z0-9_./-]+$") then return translate("Invalid core path") end
  local line = require("luci.sys").exec(util.shellquote(bin) .. " version 2>/dev/null | head -n 1") or ""
  local version = line:gsub("%s+$", "")
  return version ~= "" and version or translate("Not installed")
end
local install = controls:option(Button, "_install_core", translate("Install pinned Smart core"))
install.inputstyle = "apply"
function install.write(self, section)
  local bin = require("luci.model.uci").cursor():get("smartbox", "main", "binary") or "/usr/bin/sing-box-smart"
  if bin ~= "/usr/bin/sing-box-smart" and bin ~= "/usr/local/bin/sing-box-smart" then
    self.description = translate("Pinned installer supports /usr/bin/sing-box-smart or /usr/local/bin/sing-box-smart only")
    return
  end
  local rc = os.execute("/usr/libexec/smartbox-core-install >/dev/null 2>&1")
  self.description = rc == 0 and translate("Core installed") or
    translate("Installation failed; stop SmartBox and check system log")
end
local rollback = controls:option(Button, "_rollback_core", translate("Rollback Smart core"))
rollback.inputstyle = "reset"
function rollback.write(self, section)
  local bin = require("luci.model.uci").cursor():get("smartbox", "main", "binary") or "/usr/bin/sing-box-smart"
  if bin ~= "/usr/bin/sing-box-smart" and bin ~= "/usr/local/bin/sing-box-smart" then
    self.description = translate("Rollback supports /usr/bin/sing-box-smart or /usr/local/bin/sing-box-smart only")
    return
  end
  local rc = os.execute("/usr/libexec/smartbox-core-rollback >/dev/null 2>&1")
  self.description = rc == 0 and translate("Previous core restored") or
    translate("Rollback failed; stop SmartBox and check system log")
end
local status = controls:option(DummyValue, "_runtime", translate("Runtime status"))
function status.cfgvalue(self, section)
  local bin = require("luci.model.uci").cursor():get("smartbox", "main", "binary") or "/usr/bin/sing-box-smart"
  local name = bin:match("^/[A-Za-z0-9_./-]+$") and bin:match("/([^/]+)$") or "sing-box-smart"
  if os.execute("pidof " .. require("luci.util").shellquote(name) .. " >/dev/null 2>&1") == 0 then
    return translate("Running")
  end
  return translate("Stopped")
end
local start = controls:option(Button, "_start", translate("Start SmartBox"))
start.inputstyle = "apply"
function start.write(self, section)
  if require("luci.model.uci").cursor():get("smartbox", "main", "enabled") ~= "1" then
    self.description = translate("Enable the independent service and save first")
    return
  end
  local rc = os.execute("/usr/libexec/smartbox-start >/dev/null 2>&1")
  self.description = rc == 0 and translate("Start requested; refresh status") or translate("Failed; check system log and configuration")
end
local stop = controls:option(Button, "_stop", translate("Stop SmartBox"))
stop.inputstyle = "reset"
function stop.write(self, section)
  os.execute("/usr/libexec/smartbox-stop >/dev/null 2>&1")
end
return m
