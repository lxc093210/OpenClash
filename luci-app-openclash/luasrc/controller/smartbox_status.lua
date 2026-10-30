module("luci.controller.smartbox_status", package.seeall)
local http = require "luci.http"
local json = require "luci.jsonc"
local sys = require "luci.sys"
local util = require "luci.util"
local uci = require("luci.model.uci").cursor()

function index()
  if not nixio.fs.access("/etc/config/smartbox") then return end
  local p = entry({"admin","services","smartbox","status"}, template("openclash/smartbox_status"), _("Smart Ranking"), 2)
  p.leaf = true
  p.acl_depends = {"luci-app-openclash"}
  local api = entry({"admin","services","smartbox","status_data"}, call("status_data"))
  api.leaf = true
  api.acl_depends = {"luci-app-openclash"}
end

function status_data()
  http.prepare_content("application/json")
  local secret = uci:get("smartbox","main","api_secret") or ""
  local function summary()
    local result = {
      runtime = sys.exec("/usr/libexec/smartbox-status 2>/dev/null") or "",
      logs = {}
    }
    local raw = sys.exec("logread 2>/dev/null | tail -n 200") or ""
    for line in raw:gmatch("[^\r\n]+") do
      local lower = line:lower()
      if lower:find("smartbox", 1, true) or lower:find("sing-box-smart", 1, true) then
        if #secret >= 24 then
          line = line:gsub(secret:gsub("([^%w])", "%%%1"), "[redacted]")
        end
        line = line:gsub("https?://[^%s%\"'<>]+", "[redacted URL]")
        line = line:gsub("[Bb]earer%s+[%w_%-%.]+", "Bearer [redacted]")
        line = line:sub(1, 600)
        result.logs[#result.logs + 1] = line
        if #result.logs > 40 then table.remove(result.logs, 1) end
      end
    end
    return result
  end
  local state = summary()
  local port = tonumber(uci:get("smartbox","main","controller_port") or "19090")
  if not port or port ~= math.floor(port) or port < 1 or port > 65535 then
    state.error = "Invalid controller port"
    http.write_json(state)
    return
  end
  if not secret:match("^[%w_-]+$") or #secret < 24 then
    state.error = "SmartBox API secret is not configured"
    http.write_json(state)
    return
  end
  -- Only call the localhost controller, never a user-supplied host/URL.
  local function fetch(path)
    local cmd = "curl -fsS --max-time 3 -H " ..
      util.shellquote("Authorization: Bearer " .. secret) ..
      " " .. util.shellquote("http://127.0.0.1:" .. port .. path) ..
      " 2>/dev/null"
    return json.parse(sys.exec(cmd))
  end
  local data = fetch("/smart/weights")
  if type(data) ~= "table" or type(data.weights) ~= "table" then
    state.error = "Smart API unavailable; check the local SmartBox service"
    http.write_json(state)
    return
  end
  local details = fetch("/smart/groups")
  if type(details) == "table" and type(details.groups) == "table" then
    data.groups = details.groups
  end
  data.runtime = state.runtime
  data.logs = state.logs
  http.write_json(data)
end
