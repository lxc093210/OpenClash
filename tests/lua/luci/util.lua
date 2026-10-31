return {shellquote = function(value) return "'" .. value:gsub("'", "'\\''") .. "'" end}
