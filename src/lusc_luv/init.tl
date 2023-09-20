
local uv <const> = require("luv")
local lusc <const> = require("lusc")
local util <const> = require("lusc.util")
local LuscBackgroundRunner <const> = require("lusc_luv.background_runner")

local record lusc_luv
end

function lusc_luv.get_time():number
   return uv.hrtime() / 1e9
end

local function _get_opts(opts:lusc.Opts):lusc.Opts
   if opts == nil then
      opts = {}
   end

   util.assert(opts.time_provider == nil)

   opts = util.shallow_clone(opts)
   opts.time_provider = lusc_luv.get_time
   return opts
end

function lusc_luv.run_in_background(opts:lusc.Opts):LuscBackgroundRunner
   local runner = LuscBackgroundRunner.new()
   runner:_initialize(_get_opts(opts))
   return runner
end

function lusc_luv.run(entry_point:function(lusc.Nursery), opts:lusc.Opts)
   local pending_jobs = {entry_point}
   local coro = lusc.run(_get_opts(opts))

   while true do
      local ok, result = coroutine.resume(coro, pending_jobs)
      pending_jobs = {}

      if not ok then
         error(result)
      end

      if result == lusc.NO_MORE_TASKS_SIGNAL then
         break
      end

      util.assert(result is number)
      local seconds = result as number
      uv.sleep(math.floor(seconds * 1000))
   end
end

return lusc_luv
