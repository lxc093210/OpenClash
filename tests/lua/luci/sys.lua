local secret = "00000000000000000000000000000000"
local M = {}
function M.exec(command)
  if command:find("/smart/groups/auto/recompute", 1, true) then return "400" end
  if command:find("-w '%{http_code}'", 1, true) then return "204" end
  if command:find("smartbox-status", 1, true) then return "Process: running\n" end
  if command:find("logread", 1, true) then
    return "smartbox: " .. secret .. " https://example.invalid/private?token=abc Bearer secret123\n"
  end
  assert(command:find("curl -fsS --max-time 3 --max-filesize 1048576", 1, true))
  assert(not command:find(secret, 1, true), "API secret exposed in process arguments")
  if command:find("/smart/weights", 1, true) then
    return '{"weights":{"auto":[{"Name":"node-secret","URL":"https://example.invalid/secret","Auth":"Bearer secret123","Token":"00000000000000000000000000000000","Password":"plain-secret"}]}}'
  end
  if command:find("/smart/groups", 1, true) then
    return '{"groups":[{"name":"auto","now":"node1"}]}'
  end
  error("unexpected request")
end
return M
