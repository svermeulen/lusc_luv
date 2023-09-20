
# Lusc Luv - Structured Async/Concurrency for Lua, using Luv

`lusc_luv` provides some simple code that handles [Lusc](https://github.com/svermeulen/lusc) initialization using functionality from [Luv](https://github.com/luvit/luv)

See the [Lusc](https://github.com/svermeulen/lusc) docs first before reading this

Simple Example
---

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

API Reference
---

