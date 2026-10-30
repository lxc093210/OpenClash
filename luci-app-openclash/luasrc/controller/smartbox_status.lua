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
  local port = tonumber(uci:get("smartbox","main","controller_port") or "19090")
  if not port or port < 1 or port > 65535 then
    http.write_json({error="Invalid controller port"})
    return
  end
  -- Only call the localhost controller, never user-supplied host/URL.
  local secret = uci:get("smartbox","main","api_secret") or ""
  local function fetch(path)
    local cmd = "curl -fsS --max-time 3 -H " ..
      util.shellquote("Authorization: Bearer " .. secret) ..
      " " .. util.shellquote("http://127.0.0.1:" .. port .. path) ..
      " 2>/dev/null"
    return json.parse(sys.exec(cmd))
  end
  local data = fetch("/smart/weights")
  if type(data) ~= "table" or type(data.weights) ~= "table" then
    http.write_json({error="Smart API unavailable; check the local SmartBox service"})
    return
  end
  local details = fetch("/smart/groups")
  if type(details) == "table" and type(details.groups) == "table" then
    data.groups = details.groups
  end
  http.write_json(data)
end
