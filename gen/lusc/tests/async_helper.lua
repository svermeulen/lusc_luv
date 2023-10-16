
local lusc = require("lusc")
local util = require("lusc.internal.util")
local uv = require("luv")

local test_async_helper = {}


function test_async_helper.run_lusc(handler, timeout_seconds)
   if timeout_seconds == nil then
      timeout_seconds = 0.5
   end

   local received_on_completed = false
   local root_err

   util.assert(not lusc.has_started())
   lusc.start({
      generate_debug_names = true,
      on_completed = function(e)
         received_on_completed = true
         root_err = e
      end,
   })

   lusc.schedule(handler, { name = "test_async_helper" })

   lusc.stop({
      fail_after = timeout_seconds,
   })

   util.assert(uv.loop_mode() == nil)
   local result, err = uv.run()
   util.assert(result == false, err)

   util.assert(received_on_completed)
   util.assert(root_err == nil, tostring(root_err))
   util.assert(not lusc.has_started())
end

function test_async_helper.measure_time(handler)
   local start_time = lusc.get_time()
   handler()
   local end_time = lusc.get_time()
   return end_time - start_time
end

return test_async_helper
