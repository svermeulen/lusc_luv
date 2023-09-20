
local record lusc_luv
   get_time:function():number
   run_in_background:function(opts:lusc.Opts):LuscBackgroundRunner
   run:function(entry_point:function(lusc.Nursery), opts:lusc.Opts)
end

return lusc_luv
