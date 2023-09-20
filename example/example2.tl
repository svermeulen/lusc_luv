
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

local runner = lusc_luv.run_in_background()

-- After creating the runner, we can cache this and add tasks to it
-- throughout the lifetime of our application

-- For example:
runner:schedule(main)

-- Then, later on when our application is closing we need to shut down
-- properly, which we can do like this:

-- If you don't want to force shutdown you might want to call cancel:
-- runner:cancel()

-- wait will block until all tasks are complete
runner:wait()

-- End the lusc_luv event loop.  Note that dispose() requires that all tasks have
-- ended before calling, so it's common to call wait() first
runner:dispose()
