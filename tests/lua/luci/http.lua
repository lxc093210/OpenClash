local M = {}
function M.prepare_content(_) end
function M.write_json(data) M.last = data end
function M.formvalue(name) return M.form and M.form[name] end
return M
