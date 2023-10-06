
local lusc <const> = require("lusc")

local record lusc_luv
   record BackgroundRunner
      wait:function()
      dispose:function()
      cancel:function()
      schedule:function(job:function(lusc.Nursery))
   end

   get_time:function():number
   run:function(entry_point:function(lusc.Nursery), opts:lusc.Opts)
end

return lusc_luv
