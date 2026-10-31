local M = {}
function M.prepare_content(_) end
function M.write_json(data) M.last = data end
return M
