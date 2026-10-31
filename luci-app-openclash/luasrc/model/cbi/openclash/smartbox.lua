local m = Map("smartbox", translate("sing-box Smart (experimental)"),
 translate("Independent localhost-only test runner. Does not change OpenClash DNS, firewall, or TUN. May run alongside OpenClash in this localhost-only mode. It does not transparently proxy LAN clients; provider URLs are confidential. Save changes before starting the service."))

function m.on_after_commit(self)
  os.execute("chmod 0600 /etc/config/smartbox")
end

local s = m:section(NamedSection, "main", "smartbox", translate("Runtime"))
s.addremove = false
local enabled = s:option(Flag, "enabled", translate("Enable independent service"))
enabled.default = "0"
local binary = s:option(Value, "binary", translate("Smart binary path"))
binary.default = "/usr/bin/sing-box-smart"
function binary.validate(self, value)
 if value == "/usr/bin/sing-box-smart" or value == "/usr/local/bin/sing-box-smart" then return value end
 return nil, translate("Use /usr/bin/sing-box-smart or /usr/local/bin/sing-box-smart")
end
local port = s:option(Value, "listen_port", translate("Local mixed proxy port"))
port.datatype = "port"
port.default = "2088"
local controller = s:option(Value, "controller_port", translate("Local controller port"))
controller.datatype = "port"
controller.default = "19090"
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
local interval = p:option(Value, "update_interval", translate("Refresh interval"))
interval.default = "12h"
interval.rmempty = false
function interval.validate(self, value)
 local count, unit = value and value:match("^([1-9]%d*)([hm])$")
 if count and (unit == "h" or tonumber(count) >= 60) then return value end
 return nil, translate("Use an interval of at least 1 hour, for example 1h or 12h")
end

local controls = m:section(SimpleSection)
local core = controls:option(DummyValue, "_core", translate("Smart core"))
function core.cfgvalue(self, section)
  local uci = require("luci.model.uci").cursor()
  local util = require("luci.util")
  local bin = uci:get("smartbox", "main", "binary") or "/usr/bin/sing-box-smart"
  if bin ~= "/usr/bin/sing-box-smart" and bin ~= "/usr/local/bin/sing-box-smart" then return translate("Invalid core path") end
  local line = require("luci.sys").exec(util.shellquote(bin) .. " version 2>/dev/null | head -n 1") or ""
  local version = line:gsub("%s+$", "")
  return version ~= "" and version or translate("Not installed")
end
local install = controls:option(Button, "_install_core", translate("Install pinned Smart core"))
install.inputstyle = "apply"
function install.write(self, section)
  local rc = os.execute("/usr/libexec/smartbox-core-install >/dev/null 2>&1")
  self.description = rc == 0 and translate("Core installed") or
    translate("Installation failed; stop SmartBox and check system log")
end
local rollback = controls:option(Button, "_rollback_core", translate("Rollback Smart core"))
rollback.inputstyle = "reset"
function rollback.write(self, section)
  local rc = os.execute("/usr/libexec/smartbox-core-rollback >/dev/null 2>&1")
  self.description = rc == 0 and translate("Previous core restored") or
    translate("Rollback failed; stop SmartBox and check system log")
end
local status = controls:option(DummyValue, "_runtime", translate("Runtime status"))
function status.cfgvalue(self, section)
  local bin = require("luci.model.uci").cursor():get("smartbox", "main", "binary") or "/usr/bin/sing-box-smart"
  local name = (bin == "/usr/bin/sing-box-smart" or bin == "/usr/local/bin/sing-box-smart") and bin:match("/([^/]+)$") or "sing-box-smart"
  if os.execute("pidof " .. require("luci.util").shellquote(name) .. " >/dev/null 2>&1") == 0 then
    return translate("Running (local test)")
  end
  return translate("Stopped")
end
local start = controls:option(Button, "_start", translate("Start local test"))
start.inputstyle = "apply"
function start.write(self, section)
  if require("luci.model.uci").cursor():get("smartbox", "main", "enabled") ~= "1" then
    self.description = translate("Enable the independent service and save first")
    return
  end
  local rc = os.execute("/etc/init.d/smartbox start >/dev/null 2>&1")
  self.description = rc == 0 and translate("Start requested; refresh status") or translate("Failed; check system log and configuration")
end
local stop = controls:option(Button, "_stop", translate("Stop local test"))
stop.inputstyle = "reset"
function stop.write(self, section)
  os.execute("/etc/init.d/smartbox stop >/dev/null 2>&1")
end
return m
