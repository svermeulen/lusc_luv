
local uv <const> = require("luv")
local lusc <const> = require("lusc")
local util <const> = require("lusc.util")

local milliseconds_per_second = 1000.0

local record lusc_luv
   record BackgroundRunner
      _coro:thread
      _pending_jobs:{function(lusc.Nursery)}
      _timer:uv.Timer
      _has_errored:boolean
      _has_initialized:boolean

      _resume:function(self: BackgroundRunner)
   end
end

function lusc_luv.BackgroundRunner.new():lusc_luv.BackgroundRunner
   return setmetatable(
      {
         _coro = nil,
         _pending_jobs = {},
         _timer = uv.new_timer(),
         _has_errored = false,
         _has_initialized = false,
      } as lusc_luv.BackgroundRunner,
      { __index = lusc_luv.BackgroundRunner } as metatable<lusc_luv.BackgroundRunner>)
end

function lusc_luv.BackgroundRunner:_restart_timer(seconds:number)
   util.assert(not self._has_errored)
   self._timer:stop()
   self._timer:start(math.floor(seconds * milliseconds_per_second), 0, function() self:_resume() end)
end

function lusc_luv.BackgroundRunner:_resume()
   util.assert(not self._has_errored)

   local jobs = self._pending_jobs
   self._pending_jobs = {}
   local ok, result = coroutine.resume(self._coro, jobs)

   if not ok then
      self._has_errored = true
      error(result)
   end

   if result ~= lusc.NO_MORE_TASKS_SIGNAL then
      util.assert(result is number)
      self:_restart_timer(result as number)
   end
end

function lusc_luv.BackgroundRunner:_initialize(opts:lusc.Opts)
   util.assert(not self._has_initialized)
   util.assert(not self._has_errored)
   util.assert(self._coro == nil)

   self._has_initialized = true
   self._coro = lusc.run(opts)
end

function lusc_luv.BackgroundRunner:wait()
   util.assert(self._has_initialized)
   util.assert(not self._has_errored)

   self._timer:stop()

   local final_jobs = self._pending_jobs
   self._pending_jobs = {}

   while true do
      util.assert(not self._has_errored)
      util.assert(#self._pending_jobs == 0)
      local ok, result = coroutine.resume(self._coro, final_jobs)
      final_jobs = {}

      if not ok then
         self._has_errored = true
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

function lusc_luv.BackgroundRunner:dispose()
   util.assert(self._has_initialized)
   util.assert(not self._has_errored)
   util.assert(#self._pending_jobs == 0)

   local ok, result = coroutine.resume(self._coro, lusc.QUIT_SIGNAL)

   if not ok then
      self._has_errored = true
      error(result)
   end

   util.assert(coroutine.status(self._coro) == "dead")
end

function lusc_luv.BackgroundRunner:schedule(job:function(lusc.Nursery))
   util.assert(self._has_initialized)
   util.assert(not self._has_errored)

   table.insert(self._pending_jobs, job)
   self:_restart_timer(0)
end

function lusc_luv.BackgroundRunner:cancel()
   self:schedule(function(nursery:lusc.Nursery)
      nursery:cancel()
   end)
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

function lusc_luv.run_in_background(opts:lusc.Opts):lusc_luv.BackgroundRunner
   local runner = lusc_luv.BackgroundRunner.new()
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
