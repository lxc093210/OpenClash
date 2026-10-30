-- CI-only module: a JSON encoder with the same method exposed by luci.jsonc.
local cjson = require("cjson")
return {stringify = function(obj) return cjson.encode(obj) end}
