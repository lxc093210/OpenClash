local m = Map("smartbox", translate("sing-box Smart (experimental)"),
 translate("Independent localhost-only test runner. Does not change OpenClash DNS, firewall, or TUN. Disable OpenClash before enabling SmartBox; provider URLs are confidential."))

local s = m:section(NamedSection, "main", "smartbox", translate("Runtime"))
s.addremove = false
local enabled = s:option(Flag, "enabled", translate("Enable independent service"))
enabled.default = "0"
local binary = s:option(Value, "binary", translate("Smart binary path"))
binary.default = "/usr/bin/sing-box-smart"
local port = s:option(Value, "listen_port", translate("Local mixed proxy port"))
port.datatype = "port"
port.default = "2088"
local controller = s:option(Value, "controller_port", translate("Local controller port"))
controller.datatype = "port"
controller.default = "19090"
local secret = s:option(Value, "api_secret", translate("API secret"))
secret.password = true
secret.rmempty = true

local p = m:section(TypedSection, "provider", translate("HTTPS subscriptions"))
p.anonymous = true
p.addremove = true
local on = p:option(Flag, "enabled", translate("Enabled"))
on.default = "0"
local name = p:option(Value, "name", translate("Unique name"))
name.datatype = "uciname"
name.rmempty = false
local url = p:option(Value, "url", translate("Subscription URL"))
url.password = true
url.rmempty = false
function url.validate(self, value, section)
 if value and value:match("^https://") then return value end
 return nil, translate("An HTTPS URL is required")
end
local interval = p:option(Value, "update_interval", translate("Refresh interval"))
interval.default = "12h"
interval.rmempty = false
return m
