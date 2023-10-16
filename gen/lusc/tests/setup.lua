local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local math = _tl_compat and _tl_compat.math or math; local os = _tl_compat and _tl_compat.os or os
local util = require('lusc.internal.util')

util.set_log_handler(function(message)
   print(message)
end)

math.randomseed(os.time())




math.random(); math.random(); math.random()
