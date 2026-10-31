module("luci.controller.smartbox_status", package.seeall)
local http = require "luci.http"
local json = require "luci.jsonc"
local sys = require "luci.sys"
local util = require "luci.util"
local nixio = require "nixio"
local fs = require "nixio.fs"
local uci = require("luci.model.uci").cursor()

function index()
  if not nixio.fs.access("/etc/config/smartbox") then return end
  local p = entry({"admin","services","smartbox","status"}, template("openclash/smartbox_status"), _("Smart Ranking"), 2)
  p.leaf = true
  p.acl_depends = {"luci-app-openclash"}
  local api = entry({"admin","services","smartbox","status_data"}, call("status_data"))
  api.leaf = true
  api.acl_depends = {"luci-app-openclash"}
  local action = entry({"admin","services","smartbox","action"}, call("action"))
  action.leaf = true
  action.acl_depends = {"luci-app-openclash"}
end

local function api_header(secret)
  local dir = "/etc/sing-box-smart"
  if not fs.chmod(dir, 448) then return nil, "SmartBox configuration directory is unavailable" end
  local suffix = tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
  local path = dir .. "/.api-action-" .. nixio.getpid() .. "-" .. suffix
  local file = io.open(path, "w")
  if not file then return nil, "Smart API header could not be prepared" end
  file:write("Authorization: Bearer ", secret, "\n")
  file:close()
  if not fs.chmod(path, 384) then
    os.remove(path)
    return nil, "Smart API header permissions could not be set"
  end
  return path
end

local function redact_action_response(value, secret)
  value = value or ""
  if #secret >= 24 then
    value = value:gsub(secret:gsub("([^%w])", "%%%1"), "[redacted]")
  end
  value = value:gsub("https?://[^%s%\"'<>]+", "[redacted URL]")
  value = value:gsub("[Bb]earer%s+[%w_%-%.]+", "Bearer [redacted]")
  value = value:gsub('("[^"\r\n]*[Ss]ecret[^"\r\n]*"%s*:%s*")[^"]*"', '%1[redacted]"')
  value = value:gsub('("[^"\r\n]*[Tt]oken[^"\r\n]*"%s*:%s*")[^"]*"', '%1[redacted]"')
  value = value:gsub('("[^"\r\n]*[Pp]assword[^"\r\n]*"%s*:%s*")[^"]*"', '%1[redacted]"')
  value = value:gsub('("[^"\r\n]*[Aa]uthorization[^"\r\n]*"%s*:%s*")[^"]*"', '%1[redacted]"')
  return value
end

function action()
  http.prepare_content("application/json")
  local secret = uci:get("smartbox", "main", "api_secret") or ""
  if not secret:match("^[%w_-]+$") or #secret < 24 then
    http.write_json({error = "SmartBox API secret is not configured"})
    return
  end
  local port = tonumber(uci:get("smartbox", "main", "controller_port") or "19090")
  local action_name = http.formvalue("action") or ""
  local group = http.formvalue("group") or ""
  local node = http.formvalue("node") or ""
  if not port or port ~= math.floor(port) or port < 1 or port > 65535 then
    http.write_json({error = "Invalid controller port"})
    return
  end
  if not group:match("^[%w_-]+$") or #group > 80 then
    http.write_json({error = "Invalid Smart group"})
    return
  end
  local method, path, payload
  if action_name == "recompute" then
    method, path = "POST", "/smart/groups/" .. group .. "/recompute"
  elseif action_name == "clear" then
    method, path = "POST", "/smart/groups/" .. group .. "/clear-selection"
  elseif action_name == "select" then
    if node == "" or #node > 200 or node:find("[%c]", 1) then
      http.write_json({error = "Invalid Smart node"})
      return
    end
    method, path = "PUT", "/proxies/" .. group
    payload = json.stringify({name = node})
  elseif action_name == "unselect" then
    method, path = "DELETE", "/proxies/" .. group
  else
    http.write_json({error = "Unsupported Smart action"})
    return
  end
  local header_path, header_error = api_header(secret)
  if not header_path then
    http.write_json({error = header_error})
    return
  end
  -- Keep the response in the root-only SmartBox directory. A predictable
  -- world-writable /tmp path would allow a symlink attack against uhttpd.
  local response_path = "/etc/sing-box-smart/.api-response-" .. nixio.getpid() ..
    "-" .. tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
  local command = "curl -sS --max-time 5 --max-filesize 1048576 -o " ..
    util.shellquote(response_path) .. " -w '%{http_code}' -X " .. method ..
    " -H " .. util.shellquote("@" .. header_path)
  if payload then
    command = command .. " -H 'Content-Type: application/json' --data " .. util.shellquote(payload)
  end
  command = command .. " " .. util.shellquote("http://127.0.0.1:" .. port .. path) .. " 2>/dev/null"
  local code = tonumber(sys.exec(command) or "") or 0
  local body = fs.readfile(response_path) or ""
  os.remove(header_path)
  os.remove(response_path)
  if code < 200 or code >= 300 then
    http.write_json({error = "Smart API action failed", status = code,
      response = redact_action_response(body:sub(1, 1000), secret)})
    return
  end
  http.write_json({ok = true, status = code})
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
  local dir = "/etc/sing-box-smart"
  if not fs.chmod(dir, 448) then
    state.error = "SmartBox configuration directory is unavailable"
    http.write_json(state)
    return
  end
  local header_path = dir .. "/.api-header-" .. nixio.getpid()
  local header = io.open(header_path, "w")
  if not header then
    state.error = "SmartBox API header could not be prepared"
    http.write_json(state)
    return
  end
  header:write("Authorization: Bearer ", secret, "\n")
  header:close()
  if not fs.chmod(header_path, 384) then
    os.remove(header_path)
    state.error = "SmartBox API header permissions could not be set"
    http.write_json(state)
    return
  end
  -- Only call the localhost controller, never a user-supplied host/URL.
  local function fetch(path)
    local cmd = "curl -fsS --max-time 3 --max-filesize 1048576 -H " ..
      util.shellquote("@" .. header_path) ..
      " " .. util.shellquote("http://127.0.0.1:" .. port .. path) ..
      " 2>/dev/null"
    local ok, result = pcall(json.parse, sys.exec(cmd))
    return ok and result or nil
  end
  local data = fetch("/smart/weights")
  if type(data) ~= "table" or type(data.weights) ~= "table" then
    os.remove(header_path)
    state.error = "Smart API unavailable; check the local SmartBox service"
    http.write_json(state)
    return
  end
  local details = fetch("/smart/groups")
  if type(details) == "table" and type(details.groups) == "table" then
    data.groups = details.groups
  end

  -- Smart node metadata can contain provider URLs or authorization material.
  -- Keep the authenticated LuCI view useful while ensuring the response cannot
  -- accidentally echo credentials returned by a core or a custom provider.
  local function redact(value, key)
    if type(key) == "string" then
      local lower_key = key:lower()
      if type(value) == "string" and lower_key:match("url") then return "[redacted URL]" end
      local sensitive_key = lower_key:find("secret", 1, true) or
        lower_key:find("token", 1, true) or
        lower_key:find("password", 1, true) or
        lower_key:find("authorization", 1, true) or
        lower_key:find("credential", 1, true) or
        lower_key:find("header", 1, true)
      if type(value) == "string" and sensitive_key then
        return "[redacted]"
      end
    end
    if type(value) == "table" then
      for key, item in pairs(value) do
        value[key] = redact(item, key)
      end
      return value
    end
    if type(value) ~= "string" then return value end
    if #secret >= 24 then
      value = value:gsub(secret:gsub("([^%w])", "%%%1"), "[redacted]")
    end
    value = value:gsub("https?://[^%s%\"'<>]+", "[redacted URL]")
    return value:gsub("[Bb]earer%s+[%w_%-%.]+", "Bearer [redacted]")
  end
  data = redact(data)
  os.remove(header_path)
  data.runtime = state.runtime
  data.logs = state.logs
  http.write_json(data)
end
