
local lusc <const> = require("lusc")
local lusc_luv <const> = require("lusc_luv")

local function main()
   print("Waiting 1 second...")
   lusc.await_sleep(1)
   print("Creating child tasks...")

   -- This will run both child tasks in parallel, so
   -- the total time will be 1 second, not 2
   lusc.open_nursery(function(nursery:lusc.Nursery)
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

   -- Note also that the nursery will block until all child tasks complete
   print("Completed all child tasks")
end

lusc_luv.run(main)
