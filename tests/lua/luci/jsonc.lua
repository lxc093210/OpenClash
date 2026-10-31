local cjson = require("cjson")
return {stringify = cjson.encode, parse = cjson.decode}
