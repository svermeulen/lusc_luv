
# Lusc Luv
 
## Structured Async/Concurrency for Lua, using Luv

This library is a fork of [Lusc](https://github.com/svermeulen/lusc) which runs on top of the [Luv](https://github.com/luvit/luv) event loop

See the [Lusc](https://github.com/svermeulen/lusc) docs first before reading this

Installation
---

`luarocks install lusc_luv`

Differences with Lusc
---

1. Must be started and stopped explicitly.  Instead of calling `lusc.run` you need to call `lusc.start` and then when you want it to end, `lusc.stop`.  You may also call `lusc.stop` immediately, which will end lusc when all current tasks complete.

2. There are no entry point functions passed to `lusc.start`.  Instead, every time you want to run something underneath `lusc`, you call `lusc.schedule`, which will cause your function to run the next event loop iteration.  Long running async tasks can also check the `lusc.stop_requested()` method and then gracefully shut down.

Usage with Luv API
---

Luv has many async methods which require that a callback function be passed in as a parameter.   lusc_luv therefore comes with an adapter class that converts these methods to lusc-style await methods instead.  So instead of calling `luv.fs_open(path, flags, mode, callback)` you can import `luv_async` and then call `luv_async.await_open(path, flags, mode)`.  For more examples, see `luv_async_spec.tl`

API Reference
---

```lua

-- NOTE - The code here is not valid Lua code - it is Teal code, which gets
-- compiled to Lua
-- But can be used as reference for your lua code to understand the API and the methods/types
local record lusc
   record Scheduler
      schedule:function(Scheduler, delay_seconds:number, callback:function())
      dispose:function(Scheduler)
   end

   record DefaultScheduler
      schedule:function(DefaultScheduler, delay_seconds:number, callback:function())
      dispose:function(DefaultScheduler)

      new:function():DefaultScheduler
   end

   record Channel<T>
      --- Only needed when there is a buffer max size
      -- @return true if the receiving side is closed, in which
      -- case there is no need to send any more values
      await_send:function(Channel<T>, value:T)

      --- raises an error if the buffer is full
      -- @return true if the receiving side is closed, in which
      -- case there is no need to send any more values
      send:function(Channel<T>, value:T)

      --- @return true if both the sending side is closed and there are no more
      -- @return received value
      -- values to receive
      await_receive_next:function(Channel<T>):T, boolean

      --- Receives all values, until sender is closed
      await_receive_all:function(Channel<T>):function():T

      --- raises an error if nothing is there to receive
      -- @return received value
      -- @return true if both the sending side is closed and there are no more
      -- values to receive
      receive_next:function(Channel<T>):T, boolean

      --- Indicates that the sender has completed and receiver can end
      close:function(Channel<T>)

      -- Just calls close() after the given function completes
      close_after:function(Channel<T>, function())
   end

   record Opts
      -- Default: false
      generate_debug_names:boolean

      -- err is nil when completed successfully
      on_completed: function(err:ErrorGroup)

      -- Optional - by default it uses luv timer
      scheduler_factory: function():Scheduler
   end

   record ErrorGroup
      errors:{any}
      new:function({any}):ErrorGroup
   end

   record Task
      record Opts
         name:string
      end

      parent: Task
   end

   record Event
      is_set:boolean

      set:function(Event)
      await:function(Event)
   end

   record CancelledError
   end

   record DeadlineOpts
      -- note: can only set one of these
      move_on_after:number
      move_on_at:number
      fail_after:number
      fail_at:number
   end

   record CancelScope
      record Opts
         shielded: boolean
         name:string

         -- note: can only set one of these
         move_on_after:number
         move_on_at:number
         fail_after:number
         fail_at:number
      end

      record ShortcutOpts
         shielded: boolean
         name:string
      end

      record Result
         was_cancelled: boolean
         hit_deadline: boolean
      end

      cancel:function(CancelScope)
   end

   record Nursery
      record Opts
         name:string

         shielded: boolean

         -- note: can only set one of these
         move_on_after:number
         move_on_at:number
         fail_after:number
         fail_at:number
      end

      cancel_scope: CancelScope

      -- TODO
      -- start:function()

      start_soon:function(self: Nursery, func:function(), Task.Opts)
   end

   open_nursery:function(handler:function(nursery:Nursery), opts:Nursery.Opts):CancelScope.Result
   get_time:function():number
   await_sleep:function(seconds:number)
   await_until:function(until_time:number)
   await_forever:function()
   new_event:function():Event
   start:function(opts:Opts)

   -- Note that this will only cancel tasks if one of the move_on* or fail_* options
   -- are provided.  Otherwise it will wait forever for tasks to complete gracefully
   -- Note also that if block_until_stopped is provided, it will block 
   stop:function(opts:DeadlineOpts)

   -- Long running tasks can check this periodically, and then shut down
   -- gracefully, instead of relying on cancels
   stop_requested:function():boolean

   -- If true, then the current code is being executed
   -- under the lusc task loop and therefore lusc await
   -- methods can be used
   is_processing:function():boolean

   move_on_after:function(delay_seconds:number, handler:function(scope:CancelScope), opts:CancelScope.ShortcutOpts):CancelScope.Result
   move_on_at:function(delay_seconds:number, handler:function(scope:CancelScope), opts:CancelScope.ShortcutOpts):CancelScope.Result
   fail_after:function(delay_seconds:number, handler:function(scope:CancelScope), opts:CancelScope.ShortcutOpts):CancelScope.Result
   fail_at:function(delay_seconds:number, handler:function(scope:CancelScope), opts:CancelScope.ShortcutOpts):CancelScope.Result

   cancel_scope:function(handler:function(scope:CancelScope), opts:CancelScope.Opts):CancelScope.Result

   --- @return true if the given object is an instance of ErrorGroup
   -- and also that it only consists of the cancelled error
   is_cancelled_error:function(err:any):boolean

   schedule:function(handler:function(), opts:Task.Opts)

   schedule_wrap: function(function(), opts:Task.Opts): function()
   schedule_wrap: function<T>(function(T), opts:Task.Opts): function(T)
   schedule_wrap: function<T1,T2>(function(T1, T2), opts:Task.Opts): function(T1, T2)

   has_started:function():boolean

   get_root_nursery:function():Nursery

   cancel_all:function()
   open_channel:function<T>(max_buffer_size:integer):Channel<T>

   get_running_task:function():Task
   try_get_running_task:function():Task
end
```

# Strong Typing Support

Note that this library is implemented using [Teal](https://github.com/teal-language/tl) and that all the lua files here are generated.  If you are also using Teal, and want your calls to the API strongly typed, you can copy and paste the teal type definition files from `/dist/lusc_luv.d.tl` into your project (or just add a path directly to the source code here in your tlconfig.lua file)
