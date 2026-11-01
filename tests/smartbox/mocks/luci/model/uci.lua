-- Minimal fixture for running the production generator in CI without OpenWrt.
local M = {}
function M.cursor()
  return {
    get_all = function(_, pkg, section)
      assert(pkg == "smartbox" and section == "main")
      return {
        api_secret = os.getenv("MOCK_SECRET") or string.rep("a", 40),
        mode = os.getenv("MOCK_MODE") or "sidecar",
        tun_interface = "smarttun",
        tun_address = "172.19.0.1/30",
        tun_auto_redirect = os.getenv("MOCK_AUTO_REDIRECT") or "0",
        fakeip_enabled = os.getenv("MOCK_FAKEIP") or "0",
        fakeip_ipv4_range = os.getenv("MOCK_FAKEIP_IPV4") or "198.18.0.0/15",
        fakeip_ipv6_range = os.getenv("MOCK_FAKEIP_IPV6") or "2001:2::/48",
        listen_port = os.getenv("MOCK_PROXY_PORT") or "2088",
        controller_port = "19090",
        probe_url = "https://www.gstatic.com/generate_204",
        expected_status = os.getenv("MOCK_EXPECTED_STATUS") or "204",
        prefer_asn = "0",
        tolerance = "0",
        sample_rate = os.getenv("MOCK_SAMPLE_RATE") or "0.25",
        collect_data = "1",
        use_lightgbm = "1",
        exclude_pattern = "(?i)剩余|到期|官网",
        policy_priority = ""
      }
    end,
    foreach = function(_, pkg, typ, callback)
      assert(pkg == "smartbox")
      if typ == "provider" then
        local url = os.getenv("MOCK_PROVIDER_URL") or "https://example.test/subscribe?token=dummy"
        local interval = os.getenv("MOCK_INTERVAL") or "12h"
        local tag = os.getenv("MOCK_PROVIDER_NAME") or "airport_test"
        callback({enabled="1", name=tag, url=url, user_agent="clash", update_interval=interval})
        if os.getenv("MOCK_DUPLICATE") == "1" then
          callback({enabled="1", name=tag, url=url, update_interval=interval})
        end
      elseif typ == "device_policy" and os.getenv("MOCK_DEVICE_POLICY") == "1" then
        local cidr = os.getenv("MOCK_BAD_POLICY") == "1" and "192.168.1.1/33" or "192.168.1.100/32"
        local target = os.getenv("MOCK_BAD_POLICY") == "1" and "invalid" or "direct"
        callback({enabled="1", source_ip_cidr=cidr, target=target})
      elseif typ == "domain_policy" and os.getenv("MOCK_DOMAIN_POLICY") == "1" then
        local suffix = os.getenv("MOCK_BAD_POLICY") == "1" and "bad..example" or "example.com"
        callback({enabled="1", domain_suffix=suffix, target="reject"})
      elseif typ ~= "device_policy" and typ ~= "domain_policy" then
        error("unexpected SmartBox section type: " .. tostring(typ))
      end
    end
  }
end
return M
