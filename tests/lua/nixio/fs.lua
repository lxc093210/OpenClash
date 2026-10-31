return {
  chmod = function() return true end,
  readfile = function() return "failure https://example.invalid/private Bearer secret123 00000000000000000000000000000000" end
}
