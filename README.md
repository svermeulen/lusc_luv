
# Lusc Luv
 
## Structured Async/Concurrency for Lua, using Luv

This library just provides some simple code that handles [Lusc](https://github.com/svermeulen/lusc) initialization using functionality from [Luv](https://github.com/luvit/luv)

See the [Lusc](https://github.com/svermeulen/lusc) docs first before reading this

Simple Examples
---

When running LuscLuv, you can either execute it in a blocking or non-blocking way.  The following example shows how to run it in a blocking way by calling `lusc_luv.run`:

```lua
local lusc = require("lusc")
local lusc_luv = require("lusc_luv")

local function main()
   print("Waiting 1 second...")
   lusc.await_sleep(1)
   print("Creating child tasks...")

   -- This will run both child tasks in parallel, so
   -- the total time will be 1 second, not 2
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
   -- Note that the nursery will block here until all child tasks complete

   print("Completed all child tasks")
end

lusc_luv.run(main)
```

In the above code, lua execution will block on the line `lusc_luv.run(main)` until all tasks within `main` have fully completed.  Internally, `lusc_luv` calls `luv.sleep` when it is waiting to execute future tasks, which means that if there's any other code that is running on top of the Luv event loop, it will be blocked until the `lusc_luv.run` completes.

To address this problem for these cases, we also provide `lusc_luv.run_in_background`.  For example:

```lua
local lusc = require("lusc")
local lusc_luv = require("lusc_luv")

local function main()
   print("Waiting 1 second...")
   lusc.await_sleep(1)
   print("Creating child tasks...")

   -- This will run both child tasks in parallel, so
   -- the total time will be 1 second, not 2
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
   -- Note that the nursery will block here until all child tasks complete

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
```

API Reference
---

```lua
-- NOTE - The code here is not valid Lua code - it is Teal code, which gets
-- compiled to Lua
-- But can be used as reference for your lua code to understand the API and the methods/types
local record lusc_luv
   record BackgroundRunner
      -- Block until all pending tasks complete
      wait:function()

      -- Shut down the lusc_luv event loop
      -- NOTE: requires that all tasks have complete, so
      -- you might want to call wait() first (and also maybe cancel() before that)
      dispose:function()

      -- calls cancel() on the root nursery
      cancel:function()

      -- Schedule the given function to execute immediately on next event loop iteration
      schedule:function(job:function(lusc.Nursery))
   end

   get_time:function():number
   run_in_background:function(opts:lusc.Opts):LuscBackgroundRunner
   run:function(entry_point:function(lusc.Nursery), opts:lusc.Opts)
end
```

# Strong Typing Support

Note that this library is implemented using [Teal](https://github.com/teal-language/tl) and that all the lua files here are generated.  If you are also using Teal, and want your calls to the API strongly typed, you can copy and paste the teal type definition files from `/dist/lusc_luv.d.tl` into your project (or just add a path directly to the source code here in your tlconfig.lua file)
