module("luci.controller.smartbox", package.seeall)
function index()
  if not nixio.fs.access("/etc/config/smartbox") then return end
  local p = entry({"admin","services","smartbox"}, cbi("openclash/smartbox"), _("SmartBox (Experimental)"), 51)
  p.dependent = true
  p.acl_depends = {"luci-app-openclash"}
end
