local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local coroutine = _tl_compat and _tl_compat.coroutine or coroutine; local math = _tl_compat and _tl_compat.math or math; local table = _tl_compat and _tl_compat.table or table
local uv = require("luv")
local lusc = require("lusc")
local util = require("lusc.util")

local milliseconds_per_second = 1000.0

local LuscBackgroundRunner = {}









function LuscBackgroundRunner.new()
   return setmetatable(
   {
      _coro = nil,
      _pending_jobs = {},
      _timer = uv.new_timer(),
      _has_errored = false,
      _has_initialized = false,
   },
   { __index = LuscBackgroundRunner })
end

function LuscBackgroundRunner:_restart_timer(seconds)
   util.assert(not self._has_errored)
   self._timer:stop()
   self._timer:start(math.floor(seconds * milliseconds_per_second), 0, function() self:_resume() end)
end

function LuscBackgroundRunner:_resume()
   util.assert(not self._has_errored)

   local jobs = self._pending_jobs
   self._pending_jobs = {}
   local ok, result = coroutine.resume(self._coro, jobs)

   if not ok then
      self._has_errored = true
      error(result)
   end

   if result ~= lusc.NO_MORE_TASKS_SIGNAL then
      util.assert(type(result) == "number")
      self:_restart_timer(result)
   end
end

function LuscBackgroundRunner:_initialize(opts)
   util.assert(not self._has_initialized)
   util.assert(not self._has_errored)
   util.assert(self._coro == nil)

   self._has_initialized = true
   self._coro = lusc.run(opts)
end

function LuscBackgroundRunner:wait()
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

      util.assert(type(result) == "number")
      local seconds = result
      uv.sleep(math.floor(seconds * 1000))
   end
end

function LuscBackgroundRunner:dispose()
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

function LuscBackgroundRunner:schedule(job)
   util.assert(self._has_initialized)
   util.assert(not self._has_errored)

   table.insert(self._pending_jobs, job)
   self:_restart_timer(0)
end

function LuscBackgroundRunner:cancel()
   self:schedule(function(nursery)
      nursery:cancel()
   end)
end

return LuscBackgroundRunner
