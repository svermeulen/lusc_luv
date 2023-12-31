local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert
local lusc = require("lusc")
local uv = require("luv")

local function main()
   print("Waiting 1 second...")
   lusc.await_sleep(1)
   print("Creating child tasks...")



   lusc.open_nursery(function(nursery)
      nursery:start_soon(function()
         print("child 1 started.  Waiting 1 second...")
         lusc.await_sleep(1)
         print("Completed child 1")
      end)

      nursery:start_soon(function()
         print("Child 2 started.  Waiting 1 second...")
         lusc.await_sleep(1)
         print("Completed child 2")
      end)
   end)


   print("Completed all child tasks")
end

lusc.start({
   generate_debug_names = true,
   on_completed = function(e)
      if e then
         print("Lusc failed: " .. tostring(e))
      end
   end,
})

lusc.schedule(main)


lusc.stop()

assert(uv.loop_mode() == nil)
local result, err = uv.run()
assert(result == false, err)
