
local lusc = require("lusc")
local lusc_luv = require("lusc_luv")

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

local runner = lusc_luv.run_in_background()





runner:schedule(main)








runner:wait()



runner:dispose()
