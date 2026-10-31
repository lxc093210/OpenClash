local target = assert(arg[1])
local header = "/tmp/smartbox-api-header-test"
local real_open, real_remove = io.open, os.remove
io.open = function(path, mode)
  if path:find("/etc/sing-box-smart/.api-header-", 1, true) == 1 then
    return real_open(header, mode)
  end
  return real_open(path, mode)
end
os.remove = function(path)
  if path:find("/etc/sing-box-smart/.api-header-", 1, true) == 1 then
    return real_remove(header)
  end
  return real_remove(path)
end

dofile(target)
luci.controller.smartbox_status.status_data()
local data = require("luci.http").last
assert(data and data.weights and data.groups and data.runtime)
assert(#data.logs == 1)
assert(not data.logs[1]:find("00000000000000000000000000000000", 1, true))
assert(not data.logs[1]:find("example.invalid", 1, true))
assert(not data.logs[1]:find("secret123", 1, true))
local node = data.weights.auto[1]
assert(node and node.Token == "[redacted]")
assert(node.URL == "[redacted URL]")
assert(node.Auth == "Bearer [redacted]")
assert(node.Password == "[redacted]")
assert(not real_open(header, "r"), "temporary API header was not removed")
