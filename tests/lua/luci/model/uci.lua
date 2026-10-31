local cursor = {}

function cursor:get(config, section, key)
  assert(config == "smartbox" and section == "main")
  if key == "api_secret" then return "00000000000000000000000000000000" end
  if key == "controller_port" then return "19090" end
end

function cursor:get_all(config, section)
  assert(config == "smartbox" and section == "main")
  return {
    api_secret = "00000000000000000000000000000000",
    listen_port = "2088",
    controller_port = os.getenv("SMARTBOX_TEST_COLLISION") and "2088" or "19090"
  }
end

function cursor:foreach(config, section, callback)
  assert(config == "smartbox" and section == "provider")
  callback({enabled = "1", name = "first", url = "https://example.invalid/one", update_interval = "12h"})
  callback({enabled = "1", name = "second", url = "https://example.invalid/two", update_interval = "1h"})
end

return {cursor = function() return cursor end}
