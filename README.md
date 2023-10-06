
# Lusc Luv
 
## Structured Async/Concurrency for Lua, using Luv

This library just provides some simple code that handles [Lusc](https://github.com/svermeulen/lusc) initialization using functionality from [Luv](https://github.com/luvit/luv)

See the [Lusc](https://github.com/svermeulen/lusc) docs first before reading this

Installation
---

`luarocks install lusc_luv`

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

In the above code, lua execution will block on the line `lusc_luv.run(main)` until all tasks within `main` have fully completed.  Internally, `lusc_luv` calls `luv.sleep` when it is waiting to execute future tasks, which means that if there's any other code that is running on top of the Luv event loop, it will be blocked until `lusc_luv.run` completes.

This means that if you want to use luv for other things in addition to the lusc bindings, then you shouldn't use this library.  There is a work-in-progress alternative to this library [here](https://github.com/svermeulen/lusc_luv_bg) that implements lusc without using sleep and instead uses luv timers, which is what you'll want to use instead.

API Reference
---

```lua
-- NOTE - The code here is not valid Lua code - it is Teal code, which gets
-- compiled to Lua
-- But can be used as reference for your lua code to understand the API and the methods/types
local record lusc_luv
   get_time:function():number
   sleep:function(seconds:number)
   run:function(entry_point:function(lusc.Nursery), opts:lusc.Opts)
end
```

# Strong Typing Support

Note that this library is implemented using [Teal](https://github.com/teal-language/tl) and that all the lua files here are generated.  If you are also using Teal, and want your calls to the API strongly typed, you can copy and paste the teal type definition files from `/dist/lusc_luv.d.tl` into your project (or just add a path directly to the source code here in your tlconfig.lua file)
