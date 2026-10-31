-- Minimal fixture for running the production generator in CI without OpenWrt.
local M = {}
function M.cursor()
  return {
    get_all = function(_, pkg, section)
      assert(pkg == "smartbox" and section == "main")
      return {
        api_secret = os.getenv("MOCK_SECRET") or string.rep("a", 40),
        listen_port = os.getenv("MOCK_PROXY_PORT") or "2088",
        controller_port = "19090"
      }
    end,
    foreach = function(_, pkg, typ, callback)
      assert(pkg == "smartbox" and typ == "provider")
      local url = os.getenv("MOCK_PROVIDER_URL") or "https://example.test/subscribe?token=dummy"
      local interval = os.getenv("MOCK_INTERVAL") or "12h"
      local tag = os.getenv("MOCK_PROVIDER_NAME") or "airport_test"
      callback({enabled="1", name=tag, url=url, user_agent="clash", update_interval=interval})
      if os.getenv("MOCK_DUPLICATE") == "1" then
        callback({enabled="1", name=tag, url=url, update_interval=interval})
      end
    end
  }
end
return M
