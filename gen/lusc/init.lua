local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local coroutine = _tl_compat and _tl_compat.coroutine or coroutine; local debug = _tl_compat and _tl_compat.debug or debug; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack









local uv = require("luv")
local milliseconds_per_second = 1000.0
local util = require("lusc.internal.util")
local Queue = require("lusc.internal.queue")

local task_counter = 0
local nursery_counter = 0
local cancel_scope_counter = 0

local generic_assert_message = "[lusc] Unknown error in lusc - enable full stack traces to inspect"

local function _get_time()
   return uv.hrtime() / 1e9
end

local function _sleep(seconds)
   uv.sleep(math.floor(seconds * milliseconds_per_second))
end

local _TASK_PAUSE = setmetatable({}, { __tostring = function() return '<task_pause>' end })
local _NO_ERROR = setmetatable({}, { __tostring = function() return '<no_error>' end })

local ChannelImpl = {}























local lusc = {Scheduler = {}, DefaultScheduler = {}, Channel = {}, Opts = {}, ErrorGroup = {}, Task = {Opts = {}, }, StickyEvent = {}, PulseEvent = {}, CancelledError = {}, StopOpts = {}, DeadlineOpts = {}, CancelScope = {Opts = {}, ShortcutOpts = {}, Result = {}, }, Nursery = {Opts = {}, }, _Runner = {}, }





















































































































































































































































































































local function _remove_element(list, item)
   local index = util.index_of(list, item)
   util.assert(index ~= -1, "Attempted to remove item from array that does not exist in array")
   table.remove(list, index)
end

local function _is_instance(obj, cls)

   return getmetatable(obj).__index == cls
end

local function _log(format, ...)
   if not util.is_log_enabled() then
      return
   end

   local current_task = lusc._current_runner:_try_get_running_task()
   local message

   if current_task == nil then
      message = string.format(format, ...)
   else
      message = string.format("[%s] " .. format, current_task._debug_task_tree, ...)
   end

   util.log("[lusc] " .. message)
end

local function _binary_search(items, item, comparator)
   local low = 1
   local high = #items

   while low <= high do
      local mid = math.floor((low + high) / 2)
      local candidate = items[mid]
      local cmp = comparator(candidate, item)

      if cmp == 0 then
         return mid
      elseif cmp > 0 then
         low = mid + 1
      else
         high = mid - 1
      end
   end
   return low
end



function lusc.DefaultScheduler.new()
   return setmetatable(
   {
      _step_timer = uv.new_timer(),
   },
   { __index = lusc.DefaultScheduler })
end

function lusc.DefaultScheduler:schedule(min_time, callback)
   local function restart_timer()
      self._step_timer:stop()
      local delay = math.max(0, min_time - _get_time())





      assert(self._step_timer:start(math.floor(delay * milliseconds_per_second), 0, function()
         local new_time = _get_time()
         if new_time < min_time then

            restart_timer()
         else

            callback()
         end
      end))
   end
   restart_timer()
end

function lusc.DefaultScheduler:dispose()
   self._step_timer:close()
end



function ChannelImpl.new(runner, max_buffer_size)
   util.assert(max_buffer_size == nil or max_buffer_size > 0, "max_buffer_size must be nil or > 0")

   return setmetatable(
   {
      _runner = runner,
      _max_buffer_size = max_buffer_size,
      _is_closed = false,
      _waiting_receive_tasks = Queue(),
      _waiting_send_tasks = Queue(),
      _buffer = Queue(),
   },
   { __index = ChannelImpl })
end

function ChannelImpl:await_send(value)
   util.assert(not self._is_closed, "[lusc] Attempted to send on a closed send channel")

   if self._max_buffer_size == nil then


      self._runner:_await_sleep(0)
      self:send(value)
      return
   end

   local has_awaited = false

   local function can_send()
      return self._buffer.count < self._max_buffer_size
   end

   local task = self._runner:_get_running_task()

   while true do
      util.assert(not self._is_closed, "[lusc] Attempted to send on a closed send channel")

      if not can_send() then
         self._waiting_send_tasks:enqueue(task)

         util.try({
            action = function()
               self._runner:_await_task_rescheduled()
            end,
            catch = function(err)



               self._waiting_send_tasks:remove_value(task)
               error(err)
            end,
         })
         util.assert(not self._waiting_send_tasks:contains(task), generic_assert_message)

         has_awaited = true
      end

      if can_send() then


         if has_awaited then
            self:send(value)
            return
         end

         self._runner:_await_sleep(0)
         has_awaited = true
      end
   end
end

function ChannelImpl:send(value)
   util.assert(not self._is_closed, "[lusc] Attempted to send on a closed send channel")

   if self._max_buffer_size ~= nil and self._buffer.count >= self._max_buffer_size then
      error("Buffer is full - cannot perform synchronous send. Use await_send instead.")
   end

   self._buffer:enqueue(value)
   _log("Added new value to channel buffer - waking up %s waiting tasks", self._waiting_receive_tasks.count)





   while not self._waiting_receive_tasks:empty() do
      self._runner:_schedule_now(self._waiting_receive_tasks:dequeue())
   end
end

function ChannelImpl:close()
   util.assert(not self._is_closed, "Attempted to close channel twice")
   self._is_closed = true


   while not self._waiting_receive_tasks:empty() do
      self._runner:_schedule_now(self._waiting_receive_tasks:dequeue())
   end
end

function ChannelImpl:close_after(func)
   util.try({
      action = func,
      finally = function()
         self:close()
      end,
   })
end

function ChannelImpl:is_closed()
   return self._is_closed
end

function ChannelImpl:as_iterator()
   return function()
      local value, is_closed = self:await_receive_next()
      if is_closed then
         return nil
      end
      return value
   end
end

function ChannelImpl:await_receive_next()
   local has_awaited = false
   local task = self._runner:_get_running_task()

   while true do
      if self._buffer:empty() then
         if self._is_closed then
            return nil, true
         end

         _log("Channel buffer is empty - awaiting for new value")
         self._waiting_receive_tasks:enqueue(task)

         util.try({
            action = function()
               self._runner:_await_task_rescheduled()
            end,
            catch = function(err)



               self._waiting_receive_tasks:remove_value(task)
               error(err)
            end,
         })
         util.assert(not self._waiting_receive_tasks:contains(task), generic_assert_message)

         has_awaited = true

         if self._buffer:empty() and self._is_closed then
            return nil, true
         end
      end

      if not self._buffer:empty() then


         if has_awaited then
            return self:receive_next()
         end

         self._runner:_await_sleep(0)
         has_awaited = true
      end
   end
end

function ChannelImpl:await_receive_all()
   return function()
      local value, is_done = self:await_receive_next()
      if is_done then
         return nil
      end

      return value
   end
end

function ChannelImpl:receive_next()
   if self._buffer:empty() then
      if self._is_closed then
         return nil, true
      end

      error("Attempted to synchronous receive on an empty lusc channel")
   end

   local val = self._buffer:dequeue()





   while not self._waiting_send_tasks:empty() do
      self._runner:_schedule_now(self._waiting_send_tasks:dequeue())
   end

   return val, false
end



function lusc.ErrorGroup.new(errors)
   local adjusted_errors = {}
   local seen_map = {}


   local function add_error(err)
      if seen_map[err] == nil then
         seen_map[err] = true
         table.insert(adjusted_errors, err)
      end
   end

   for _, err in ipairs(errors) do
      if _is_instance(err, lusc.ErrorGroup) then
         for _, sub_error in ipairs((err).errors) do
            util.assert(not _is_instance(sub_error, lusc.ErrorGroup), generic_assert_message)
            add_error(sub_error)
         end
      else
         add_error(err)
      end
   end

   local this = {
      errors = adjusted_errors,
   }

   return setmetatable(this,
   { __index = lusc.ErrorGroup, __tostring = function()
      local lines = {}
      for _, err in ipairs(this.errors) do
         table.insert(lines, tostring(err))
      end
      return table.concat(lines, '\n')
   end,
   })
end



function lusc.StickyEvent.new(runner)
   return setmetatable(
   {
      _runner = runner,
      is_set = false,
      _waiting_tasks = Queue(),
   },
   { __index = lusc.StickyEvent })
end

function lusc.StickyEvent:unset()
   self.is_set = false
end

function lusc.StickyEvent:set()
   if self.is_set then
      util.assert(self._waiting_tasks:empty(), generic_assert_message)
   else
      self.is_set = true
      local running_task = self._runner:_try_get_running_task()

      while not self._waiting_tasks:empty() do
         local task = self._waiting_tasks:dequeue()
         util.assert(task ~= running_task, generic_assert_message)
         self._runner:_schedule_now(task)
      end
   end
end

function lusc.StickyEvent:await()
   if not self.is_set then
      local task = self._runner:_get_running_task()

      util.assert(not self._waiting_tasks:contains(task), generic_assert_message)
      self._waiting_tasks:enqueue(task)

      util.try({
         action = function()
            self._runner:_await_task_rescheduled()
         end,
         catch = function(err)



            self._waiting_tasks:remove_value(task)
            error(err)
         end,
      })


      util.assert(not self._waiting_tasks:contains(task), generic_assert_message)
   end
end



function lusc.PulseEvent.new(runner)
   return setmetatable(
   {
      _runner = runner,
      _waiting_tasks = Queue(),
   },
   { __index = lusc.PulseEvent })
end

function lusc.PulseEvent:set()
   local running_task = self._runner:_try_get_running_task()

   while not self._waiting_tasks:empty() do
      local task = self._waiting_tasks:dequeue()
      util.assert(task ~= running_task, generic_assert_message)
      self._runner:_schedule_now(task)
   end
end

function lusc.PulseEvent:await()
   local task = self._runner:_get_running_task()

   util.assert(not self._waiting_tasks:contains(task), generic_assert_message)
   self._waiting_tasks:enqueue(task)

   util.try({
      action = function()
         self._runner:_await_task_rescheduled()
      end,
      catch = function(err)



         self._waiting_tasks:remove_value(task)
         error(err)
      end,
   })


   util.assert(not self._waiting_tasks:contains(task), generic_assert_message)
end



function lusc.Task.new(runner, task_handler, nursery_owner, opts)
   util.assert(runner ~= nil, generic_assert_message)
   util.assert(task_handler ~= nil, generic_assert_message)

   task_counter = task_counter + 1

   local parent_task
   if nursery_owner == nil then
      parent_task = nil
   else
      parent_task = nursery_owner._task
   end

   return setmetatable(
   {
      _id = task_counter,
      _last_schedule_time = nil,
      _is_discarded = false,
      _is_scheduled = false,
      _min_shield_depth = nil,
      _coro = coroutine.create(task_handler),
      _nursery_owner = nursery_owner,
      _parent_task = parent_task,


      parent = parent_task,

      _wait_until = nil,
      _done = lusc.StickyEvent.new(runner),
      _pending_errors = {},
      _pending_cancellation_errors = {},
      _wake_for_pending_errors = true,
      total_active_time = 0,
      _opts = opts or {},
      _runner = runner,
      _child_nursery_stack = {},
      _cancel_scope_stack = {},
      _debug_task_tree = nil,
      _debug_nursery_tree = nil,
      locals = {},
   },
   { __index = lusc.Task })
end

function lusc.Task:initialize()
   local name = self._opts.name

   if name == nil then
      if self._runner._opts.generate_debug_names then
         name = string.format('t%s', self._id)
      else
         name = '<task>'
      end
   end

   if self._runner._opts.generate_debug_names and self._parent_task ~= nil then
      self._debug_task_tree = self._parent_task._debug_task_tree .. "." .. name
   else
      self._debug_task_tree = name
   end

   if self._nursery_owner == nil then
      self._debug_nursery_tree = nil
   else
      self._debug_nursery_tree = self._nursery_owner._debug_nursery_tree
   end

   _log("Created task [%s] in nursery [%s]", self._debug_task_tree, self._debug_nursery_tree)
end

function lusc.Task:_try_get_current_nursery()
   local stack = self._child_nursery_stack

   if #stack == 0 then

      if self._nursery_owner == nil then
         return nil
      end

      return self._nursery_owner
   end

   return stack[#stack]
end

function lusc.Task:_pop_pending_errors()
   local result = self._pending_errors
   self._pending_errors = {}
   return result
end

function lusc.Task:_has_pending_errors()
   return #self._pending_errors > 0 or not util.map_is_empty(self._pending_cancellation_errors)
end

function lusc.Task:_consider_scheduling_for_pending_errors()
   if self._wake_for_pending_errors then
      if self:_has_pending_errors() then
         _log("Scheduled task [%s] to run immediately due to pending errors", self._debug_task_tree)
         self._runner:_schedule_now(self)
      else
         _log("Ignoring request to schedule task [%s] for pending error since no pending errors exist yet", self._debug_task_tree)
      end
   else
      _log("Ignoring request to schedule task [%s] for pending error due to wake_for_pending_errors flag", self._debug_task_tree)
   end
end

function lusc.Task:_save_shielded_cancel_error(err)
   util.assert(#self._cancel_scope_stack >= 1, generic_assert_message)

   local scope_to_use
   local start_index = 1

   if err._trigger_scope._task == self then
      local originating_index = err._trigger_scope._depth + 1

      start_index = originating_index + 1
   end

   for i = start_index, #self._cancel_scope_stack do
      local candidate = self._cancel_scope_stack[i]

      if candidate._shielded then
         scope_to_use = candidate
         break
      end
   end

   util.assert(scope_to_use ~= nil, generic_assert_message)

   util.assert(scope_to_use._is_running, generic_assert_message)
   util.assert(scope_to_use._shielded, generic_assert_message)
   table.insert(scope_to_use._old_pending_cancel_errors, err)
end

function lusc.Task:_enqueue_cancellation_error(err)
   _log("Received cancellation error (depth %s) for task [%s] (min_shield_depth %s)", err._trigger_scope._depth, self._debug_task_tree, self._min_shield_depth)

   if self._min_shield_depth ~= nil and (err._trigger_scope._task ~= self or err._trigger_scope._depth < self._min_shield_depth) then
      self:_save_shielded_cancel_error(err)
      _log("Suppressed cancellation error for task [%s] due to min_shield_depth check - will restore this later", self._debug_task_tree)
      return
   end

   _log("Enqueued pending cancellation error %s for task %s", err, self._debug_task_tree)
   util.assert(self._pending_cancellation_errors[err] == nil, "Attempted to enqueue the same cancellation error multiple times")
   self._pending_cancellation_errors[err] = true
   self:_consider_scheduling_for_pending_errors()
end

function lusc.Task:_enqueue_pending_error(err)
   _log("Enqueued pending error %s for task %s", err, self._debug_task_tree)
   table.insert(self._pending_errors, err)
   self:_consider_scheduling_for_pending_errors()
end



function lusc.CancelledError.new(runner, trigger_scope)
   util.assert(trigger_scope ~= nil, generic_assert_message)

   local name

   if runner._opts.generate_debug_names then
      name = string.format("<cancelled-s%s>", trigger_scope._id)
   else
      name = "<cancelled>"
   end

   local this = {
      _trigger_scope = trigger_scope,
   }

   return setmetatable(this,
   { __index = lusc.CancelledError, __tostring = function() return name end,
   })
end



function lusc.CancelScope.new(runner, task, opts)
   cancel_scope_counter = cancel_scope_counter + 1
   local id = cancel_scope_counter

   opts = opts or {}

   local shielded = opts.shielded

   if shielded == nil then
      shielded = false
   end

   local default_deadline_opts = {
      move_on_after = opts.move_on_after,
      move_on_at = opts.move_on_at,
      fail_after = opts.fail_after,
      fail_at = opts.fail_at,
   }

   local debug_name = opts.name

   if debug_name == nil then
      if runner._opts.generate_debug_names then
         debug_name = string.format("s%s", id)
      else
         debug_name = "<cancel-scope>"
      end
   end

   return setmetatable(
   {
      _id = id,
      _runner = runner,
      _task = task,
      _debug_name = debug_name,
      _depth = #task._cancel_scope_stack,
      _old_pending_cancel_errors = {},
      _default_deadline_opts = default_deadline_opts,
      _children = {},
      _shielded = shielded,
      _cancel_error = nil,
      _has_cancelled = false,
      _hit_deadline = false,
      _deadline_task = nil,
      _cancel_observers = {},
      _fail_on_deadline = false,
      _is_running = false,
   },
   { __index = lusc.CancelScope })
end

function lusc.CancelScope:_try_get_deadline_info(opts)
   local deadline
   local fail_on_deadline

   if opts.fail_at then
      util.assert(opts.move_on_after == nil and opts.move_on_at == nil and opts.fail_after == nil, generic_assert_message)
      deadline = opts.fail_at
      fail_on_deadline = true
   elseif opts.fail_after then
      util.assert(opts.move_on_after == nil and opts.move_on_at == nil, generic_assert_message)
      fail_on_deadline = true
      deadline = _get_time() + opts.fail_after
   elseif opts.move_on_at then
      util.assert(opts.move_on_after == nil, generic_assert_message)
      fail_on_deadline = false
      deadline = opts.move_on_at
   elseif opts.move_on_after then
      fail_on_deadline = false
      deadline = _get_time() + opts.move_on_after
   else
      deadline = nil
      fail_on_deadline = false
   end

   return deadline, fail_on_deadline
end

function lusc.CancelScope:_observe_cancel_request(callback)
   table.insert(self._cancel_observers, callback)
end

function lusc.CancelScope:has_cancelled()
   return self._has_cancelled
end

function lusc.CancelScope:cancel()

   util.assert(self._is_running, "[CancelScope] Attempted to cancel cancel scope that isn't running")

   _log("[CancelScope] Received cancellation request for cancel scope [%s]", self._debug_name)

   if not self._has_cancelled then
      self._has_cancelled = true
      util.assert(self._cancel_error == nil, generic_assert_message)
      self._cancel_error = lusc.CancelledError.new(self._runner, self)
      self._task:_enqueue_cancellation_error(self._cancel_error)

      for _, observer in ipairs(self._cancel_observers) do
         observer(self._cancel_error)
      end

      for _, child in ipairs(self._children) do
         if not child._shielded then
            child:cancel()
         end
      end
   end
end

function lusc.CancelScope:_set_deadline(opts)
   util.assert(self._is_running, generic_assert_message)
   util.assert(not self._hit_deadline, generic_assert_message)
   util.assert(not self._has_cancelled, generic_assert_message)


   util.assert(self._deadline_task == nil, "Attempted to set cancel scope deadline multiple times")

   local deadline, fail_on_deadline = self:_try_get_deadline_info(opts)
   self._fail_on_deadline = fail_on_deadline

   if deadline == nil then
      _log("[CancelScope] No deadline set for cancel scope [%s]", self._debug_name)
   else
      _log("[CancelScope] Setting deadline for cancel scope [%s] to %.2f seconds from now", self._debug_name, deadline - _get_time())

      local task_name

      if self._runner._opts.generate_debug_names then
         task_name = string.format("deadline-%s-%s", self._task._debug_task_tree, self._debug_name)
      end

      self._deadline_task = self._runner:_create_new_task_and_schedule(function()
         lusc.await_until(deadline)
         util.assert(not self._hit_deadline, generic_assert_message)
         self._hit_deadline = true
         self:cancel()
      end, nil, nil, { name = task_name })
   end
end

function lusc.CancelScope:_run(handler)
   util.assert(not self._is_running, generic_assert_message)
   util.assert(self._task == self._runner:_get_running_task(), generic_assert_message)

   local scope_stack = self._task._cancel_scope_stack
   local parent

   if #scope_stack > 0 then
      parent = scope_stack[#scope_stack]
      table.insert(parent._children, self)
   end

   table.insert(scope_stack, self)
   self._is_running = true
   _log("[CancelScope] Running cancel scope [%s]", self._debug_name)

   local old_min_shield_depth
   local shielded = self._shielded

   if shielded then
      old_min_shield_depth = self._task._min_shield_depth
      util.assert(self._task._min_shield_depth == nil or self._task._min_shield_depth < self._depth, generic_assert_message)
      self._task._min_shield_depth = self._depth


      for cancel_err, _ in pairs(self._task._pending_cancellation_errors) do
         if cancel_err._trigger_scope._task ~= self._task or cancel_err._trigger_scope._depth < self._depth then
            table.insert(self._old_pending_cancel_errors, cancel_err)
            self._task._pending_cancellation_errors[cancel_err] = nil
         end
      end



      util.assert(#self._task._pending_errors == 0, generic_assert_message)



      if self._task._is_scheduled then
         self._runner:_unschedule_task(self._task)
      end
   end

   self:_set_deadline(self._default_deadline_opts)

   util.try({
      action = function()
         handler(self)
      end,
      catch = function(errors)
         if not _is_instance(errors, lusc.ErrorGroup) then
            _log("Propagating error in cancel scope [%s]: %s", self._debug_name, errors)
            error(errors)
         end

         local error_group = errors
         local self_err

         for _, err in ipairs(error_group.errors) do
            if _is_instance(err, lusc.CancelledError) then
               local cancel_err = err
               if cancel_err._trigger_scope == self then
                  util.assert(self_err == nil, generic_assert_message)
                  self_err = cancel_err
               end
            end
         end

         if self_err ~= nil then
            _log("Successfully swallowed self cancel error in scope [%s]", self._debug_name)
            util.remove_element(error_group.errors, self_err)
            self._has_cancelled = true
         end

         if #error_group.errors > 0 then
            _log("Propagating %s errors in cancel scope [%s]", #error_group.errors, self._debug_name)
            error(error_group)
         end
      end,
      finally = function()
         self._is_running = false

         if shielded then
            util.assert(self._task._min_shield_depth == self._depth, generic_assert_message)
            self._task._min_shield_depth = old_min_shield_depth

            for _, cancel_err in ipairs(self._old_pending_cancel_errors) do
               util.assert(self._task._pending_cancellation_errors[cancel_err] == nil, generic_assert_message)
               self._task._pending_cancellation_errors[cancel_err] = true
               _log("Restored pending cancellation error to task [%s] in scope [%s]", self._task._debug_task_tree, self._debug_name)
            end
         end

         util.assert(scope_stack[#scope_stack] == self, generic_assert_message)
         table.remove(scope_stack)

         if parent ~= nil then
            local last_child = table.remove(parent._children)
            util.assert(last_child == self, generic_assert_message)
         end

         if self._deadline_task ~= nil then
            self._runner:_discard_task(self._deadline_task)
         end

         for cancel_err, _ in pairs(self._task._pending_cancellation_errors) do
            if cancel_err._trigger_scope == self then
               self._task._pending_cancellation_errors[cancel_err] = nil
            end
         end
      end,
   })

   if self._hit_deadline and self._fail_on_deadline then
      error("Lusc cancel scope reached given failure deadline")
   end

   _log("[CancelScope] Completed running cancel scope [%s] without errors (has_cancelled = '%s', hit_deadline = '%s')", self._debug_name, self._has_cancelled, self._hit_deadline)


   if not util.map_is_empty(self._task._pending_cancellation_errors) then
      local pending_cancel_errors = util.map_get_keys(self._task._pending_cancellation_errors)
      self._task._pending_cancellation_errors = {}
      _log("Propagating %s cancel scope pending cancellation errors", #pending_cancel_errors)
      error(lusc.ErrorGroup.new(pending_cancel_errors), 0)
   end

   return {
      was_cancelled = self._has_cancelled,
      hit_deadline = self._hit_deadline,
   }
end



function lusc.Nursery.new(runner, task, opts)
   util.assert(task ~= nil, generic_assert_message)

   nursery_counter = nursery_counter + 1

   local cancel_scope_opts = {
      shielded = opts.shielded,
      move_on_after = opts.move_on_after,
      move_on_at = opts.move_on_at,
      fail_after = opts.fail_after,
      fail_at = opts.fail_at,
   }

   local id = nursery_counter
   local name = opts.name

   if name == nil then
      if runner._opts.generate_debug_names then
         name = string.format('n%s', id)
      else
         name = '<nursery>'
      end
   end

   return setmetatable(
   {
      _id = nursery_counter,
      _runner = runner,
      _task = task,
      _name = name,
      _child_tasks = {},
      _child_nurseries = {},
      _cancel_requested = false,
      _cancel_requested_from_deadline = false,
      _debug_task_tree = task._debug_task_tree,
      _deadline = nil,
      _is_closed = false,
      _should_fail_on_deadline = nil,
      _deadline_task = nil,
      _debug_nursery_tree = nil,
      _parent_nursery = nil,
      cancel_scope = lusc.CancelScope.new(runner, task, cancel_scope_opts),
   },
   { __index = lusc.Nursery })
end

function lusc.Nursery:_cancel_sub_tasks(err)
   util.assert(not self._is_closed, "Attempted to cancel closed nursery [%s]", self._debug_nursery_tree)
   _log("Cancelling all sub tasks in nursery [%s]", self._debug_nursery_tree)

   for task, _ in pairs(self._child_tasks) do
      task:_enqueue_cancellation_error(err)
   end

   for nursery, _ in pairs(self._child_nurseries) do
      if not nursery.cancel_scope._shielded then
         nursery:_cancel_sub_tasks(err)
      end
   end
end

function lusc.Nursery:initialize()
   util.assert(not self._is_closed, generic_assert_message)

   local task_nursery_stack = self._task._child_nursery_stack

   if #task_nursery_stack == 0 then
      self._parent_nursery = self._task._nursery_owner
   else
      self._parent_nursery = task_nursery_stack[#task_nursery_stack]
   end

   table.insert(task_nursery_stack, self)

   if self._parent_nursery ~= nil then
      self._parent_nursery._child_nurseries[self] = true
   end

   if self._runner._opts.generate_debug_names and self._parent_nursery ~= nil then
      self._debug_nursery_tree = self._parent_nursery._debug_nursery_tree .. "." .. self._name
   else
      self._debug_nursery_tree = self._name
   end

   self.cancel_scope:_observe_cancel_request(function(err)
      self:_cancel_sub_tasks(err)
   end)

   _log("Created new nursery [%s]", self._debug_nursery_tree)
end

function lusc.Nursery:start_soon(task_handler, opts)
   if self.cancel_scope._has_cancelled then
      _log("Attempted to start new task in nursery [%s] after it was already cancelled - ignoring request", self._debug_nursery_tree)
      return
   end

   util.assert(not self._is_closed, "Cannot add tasks to closed nursery")
   local task = self._runner:_create_new_task_and_schedule(task_handler, self, nil, opts)
   util.assert(self._child_tasks[task] == nil, generic_assert_message)
   self._child_tasks[task] = true
end

function lusc.Nursery:close(nursery_err)
   util.assert(not self._is_closed, generic_assert_message)
   util.assert(self._task == self._runner:_get_running_task(), generic_assert_message)

   if util.is_log_enabled() then
      if util.map_is_empty(self._child_tasks) then
         _log("Closing nursery [%s] with zero tasks pending", self._debug_nursery_tree)
      else
         local child_tasks_names = {}
         for task, _ in pairs(self._child_tasks) do
            table.insert(child_tasks_names, task._debug_task_tree)
         end
         _log("Closing nursery [%s] with %s tasks pending: %s", self._debug_nursery_tree, #child_tasks_names, table.concat(child_tasks_names, ", "))
      end
   end






   if self._task._is_scheduled then
      self._runner:_unschedule_task(self._task)
   end




   util.assert(self._task._wake_for_pending_errors, generic_assert_message)
   self._task._wake_for_pending_errors = false

   local all_errors = {}

   if nursery_err ~= nil then
      table.insert(all_errors, nursery_err)
   end



   while not util.map_is_empty(self._child_tasks) do
      for child_task, _ in pairs(self._child_tasks) do
         util.try({
            action = function()
               _log("Nursery [%s] waiting for child task [%s] to complete...", self._debug_nursery_tree, child_task._debug_task_tree)
               child_task._done:await()
            end,
            catch = function(child_err)
               _log("Encountered error while waiting for task [%s] to complete while closing nursery [%s].  Will propagate it. Details: '%s'\n", child_task._debug_task_tree, self._debug_nursery_tree, child_err)
               table.insert(all_errors, child_err)
            end,
            finally = function()
               util.assert(child_task._done.is_set, generic_assert_message)
               util.assert(self._child_tasks[child_task] == nil, generic_assert_message)
               _log("Nursery [%s] finished waiting for child task [%s]", self._debug_nursery_tree, child_task._debug_task_tree)
            end,
         })
      end
   end

   self._is_closed = true
   util.assert(util.map_is_empty(self._child_nurseries), "[lusc][%s] Found non empty list of child nurseries at end of closing nursery [%s]", self._debug_task_tree, self._debug_nursery_tree)

   util.assert(not self._task._wake_for_pending_errors, generic_assert_message)
   self._task._wake_for_pending_errors = true

   for _, err in ipairs(self._task:_pop_pending_errors()) do
      table.insert(all_errors, err)
   end

   for err, _ in pairs(self._task._pending_cancellation_errors) do
      table.insert(all_errors, err)
   end

   if self._parent_nursery ~= nil then
      _log("Removing nursery [%s] from parents child nurseries list", self._debug_nursery_tree)
      self._parent_nursery._child_nurseries[self] = nil
   else
      _log("No parent nursery found for [%s], so no need to remove from child nurseries list", self._debug_nursery_tree)
   end

   local nursery_stack = self._task._child_nursery_stack
   util.assert(nursery_stack[#nursery_stack] == self, generic_assert_message)
   table.remove(nursery_stack)

   if #all_errors > 0 then
      _log("Closed nursery [%s] with %s errors", self._debug_nursery_tree, #all_errors)
      error(lusc.ErrorGroup.new(all_errors), 0)
   end

   _log("Successfully fully closed nursery [%s]", self._debug_nursery_tree)
end

function lusc.Nursery:_run(handler)
   return self.cancel_scope:_run(function()
      local main_err
      util.try({
         action = function()
            handler(self)
         end,
         catch = function(e)
            _log("Received error in main function of nursery '%s': %s", self._debug_nursery_tree, e)
            self.cancel_scope:cancel()
            main_err = e
         end,
      })
      self:close(main_err)
   end)
end



function lusc._Runner.new(opts)
   util.assert(opts ~= nil, "No options provided to lusc")

   local scheduler

   if opts.scheduler_factory == nil then
      scheduler = lusc.DefaultScheduler.new()
   else
      scheduler = opts.scheduler_factory()
      util.assert(scheduler ~= nil, generic_assert_message)
   end

   local on_completed_handlers = {}

   if opts.on_completed then
      table.insert(on_completed_handlers, opts.on_completed)
   end

   return setmetatable(
   {
      _tasks_by_coro = {},
      _task_queue = {},
      _has_started = false,
      _has_stopped = false,
      _main_nursery = nil,
      _main_task = nil,
      _on_completed_handlers = on_completed_handlers,
      _opts = opts,
      _is_within_task_loop = false,
      _stop_requested_event = nil,
      _root_error = nil,
      _initial_handlers = {},
      _next_step_time = nil,
      _stop_requested_observers = {},
      _scheduler = scheduler,
      _main_nursery_deadline_opts = nil,
   },
   { __index = lusc._Runner })
end

function lusc._Runner:_check_errored()
   util.assert(self._root_error == nil, "lusc has already encountered an error, cannot continue.  See log above for details.")
end

function lusc._Runner:_find_task_index(task)
   local function comparator(left, right)





      if left._wait_until ~= right._wait_until then
         if left._wait_until > right._wait_until then
            return 1
         end
         return -1
      end

      if left._last_schedule_time ~= right._last_schedule_time then
         if left._last_schedule_time > right._last_schedule_time then
            return 1
         end
         return -1
      end

      if left._id == right._id then
         return 0
      end

      if left._id > right._id then
         return 1
      end

      return -1
   end

   local index = _binary_search(self._task_queue, task, comparator)
   util.assert(index >= 1 and index <= #self._task_queue + 1, generic_assert_message)
   return index
end


function lusc._Runner:_try_get_time_to_next_task()
   if #self._task_queue == 0 then
      return nil
   end

   return self._task_queue[#self._task_queue]._wait_until - _get_time()
end

function lusc._Runner:_enqueue_step_in(delay)
   util.assert(delay ~= nil and delay >= 0, generic_assert_message)

   local current_time = _get_time()
   local max_time = current_time + delay

   if self._next_step_time ~= nil and self._next_step_time < max_time then
      local time_remaining = self._next_step_time - current_time
      _log("Received request to enqueue step function but ignoring since it is already scheduled to run in %.2f seconds", time_remaining)
      return
   end

   self._next_step_time = current_time + delay
   self._scheduler:schedule(self._next_step_time, function()
      util.try({
         action = function()
            _log("Received luv callback to tick event loop again")
            local new_time = _get_time()
            util.assert(new_time >= self._next_step_time, "Scheduler returned %s seconds earlier than expected", self._next_step_time - new_time)
            self._next_step_time = nil
            self:_step()
         end,
         catch = function(err)


            _log("Encountered error during lusc update.  This suggests a bug in lusc itself.  Details:\n%s", err)





            lusc._current_runner = nil
         end,
      })
   end)

   _log("Scheduled event loop to run again in %.2f seconds", delay)
end

function lusc._Runner:_enqueue_step_now()
   self:_enqueue_step_in(0)
end

function lusc._Runner:_schedule_task(task, new_wait_until)
   util.assert(not task._done.is_set, generic_assert_message)

   local current_time = _get_time()

   if task._is_scheduled then
      if task._wait_until < current_time then
         _log("Attempted to schedule task [%s] twice - ignoring new request since existing schedule is older", task._debug_task_tree)
         return
      end

      self:_unschedule_task(task)
   end

   util.assert(not task._is_scheduled, generic_assert_message)
   task._is_scheduled = true
   task._wait_until = new_wait_until

   if util.is_log_enabled() then
      local delta_time = task._wait_until - current_time
      if delta_time < 0 then
         _log("Scheduling task [%s] to run immediately in nursery [%s]", task._debug_task_tree, task._debug_nursery_tree)
      else
         _log("Scheduling task [%s] to run in %.2f seconds in nursery [%s]", task._debug_task_tree, delta_time, task._debug_nursery_tree)
      end
   end

   task._last_schedule_time = current_time
   local index = self:_find_task_index(task)
   util.assert(self._task_queue[index] ~= task, generic_assert_message)
   table.insert(self._task_queue, index, task)



   if not self._is_within_task_loop then
      self:_enqueue_step_now()
   end
end

function lusc._Runner:_schedule_now(task)
   self:_schedule_task(task, _get_time())
end

function lusc._Runner:_try_get_running_task()
   return self._tasks_by_coro[coroutine.running()]
end

function lusc._Runner:_get_running_task()
   local task = self:_try_get_running_task()
   util.assert(task ~= nil, "[lusc] Unable to find running task")
   return task
end

function lusc._Runner:_checkpoint(result)
   local pending_error = coroutine.yield(result)
   if pending_error ~= _NO_ERROR then
      _log("Received pending error back from run loop - propagating")


      error(pending_error, 0)
   end
end

function lusc._Runner:_await_task_rescheduled()
   _log("Calling coroutine.yield and passing _TASK_PAUSE")
   self:_checkpoint(_TASK_PAUSE)
end

function lusc._Runner:_await_until(until_time)
   self:_check_errored()
   util.assert(self._is_within_task_loop, generic_assert_message)
   _log("Calling coroutine.yield to wait for %.2f seconds", until_time - _get_time())
   self:_checkpoint(until_time)
end

function lusc._Runner:_set_async_local(key, value)
   local current_task = self:_get_running_task()
   current_task.locals[key] = value
end

function lusc._Runner:_try_get_async_local(key)
   local current_task = self:_get_running_task()
   return current_task.locals[key]
end

function lusc._Runner:_await_sleep(seconds)
   self:_check_errored()
   assert(seconds >= 0)
   self:_await_until(_get_time() + seconds)
end

function lusc._Runner:_await_forever()
   self:_check_errored()
   self:_await_until(math.huge)
end

function lusc._Runner:_create_new_task_and_schedule(task_handler, nursery_owner, wait_until, opts)
   if wait_until == nil then
      wait_until = _get_time()
   end
   local task = lusc.Task.new(self, task_handler, nursery_owner, opts)
   task:initialize()
   util.assert(task._coro ~= nil, generic_assert_message)
   self._tasks_by_coro[task._coro] = task
   self:_schedule_task(task, wait_until)
   return task
end

function lusc._Runner:_on_task_errored(task, error_obj)
   if self:_is_cancelled_error(error_obj) then


      _log("Received cancelled error from task [%s]", task._debug_task_tree)
      return
   end


   local traceback = debug.traceback(task._coro)

   _log("Received error from task [%s]. Will propagate it. Details: %s", task._debug_task_tree, error_obj)

   if task == self._main_task then
      util.assert(self._root_error == nil, generic_assert_message)
      self._root_error = lusc.ErrorGroup.new({ error_obj, traceback })
      self._stop_requested_event:set()
   else



      local nursery = task._nursery_owner
      util.assert(nursery ~= nil, generic_assert_message)
      nursery.cancel_scope:cancel()

      task._parent_task:_enqueue_pending_error(error_obj)
      task._parent_task:_enqueue_pending_error(traceback)
   end
end

function lusc._Runner:_subscribe_stop_requested(observer)
   util.assert(self._stop_requested_observers[observer] == nil, generic_assert_message)
   self._stop_requested_observers[observer] = true
end

function lusc._Runner:_unsubscribe_stop_requested(observer)
   util.assert(self._stop_requested_observers[observer] ~= nil, generic_assert_message, generic_assert_message)
   self._stop_requested_observers[observer] = nil
end

function lusc._Runner:_is_cancelled_error(err)
   if _is_instance(err, lusc.ErrorGroup) then


      local sub_errors = (err).errors
      util.assert(#sub_errors > 0, generic_assert_message)
      for _, sub_err in ipairs(sub_errors) do
         if not _is_instance(sub_err, lusc.CancelledError) then
            return false
         end
      end
      return true
   end

   return false
end

function lusc._Runner:_discard_task(task)
   if task._is_discarded then
      return
   end

   if task._is_scheduled then
      self:_unschedule_task(task)
   end

   if task._nursery_owner ~= nil then
      task._nursery_owner._child_tasks[task] = nil
   end
   self._tasks_by_coro[task._coro] = nil
   task._done:set()

   util.assert(#task._child_nursery_stack == 0, generic_assert_message)
   util.assert(#task._cancel_scope_stack == 0, generic_assert_message)
   util.assert(task._min_shield_depth == nil, generic_assert_message)

   task._is_discarded = true
end

function lusc._Runner:_run_task(task)
   if task._is_discarded then

      return
   end

   util.assert(not task._done.is_set, "Attempted to run task [%s] but it is already marked as done", task._debug_task_tree)

   local pending_errors = task:_pop_pending_errors()

   for err, _ in pairs(task._pending_cancellation_errors) do
      table.insert(pending_errors, err)
   end

   local coro_arg
   if #pending_errors > 0 then
      coro_arg = lusc.ErrorGroup.new(pending_errors)
      _log("Resuming task [%s] with %s pending errors", task._debug_task_tree, #pending_errors)
   else
      _log("Resuming task [%s]", task._debug_task_tree)
      coro_arg = _NO_ERROR
   end

   local task_step_start_time = _get_time()
   local resume_status, resume_result = coroutine.resume(task._coro, coro_arg)
   local task_elapsed = _get_time() - task_step_start_time
   task.total_active_time = task.total_active_time + task_elapsed
   local coro_status = coroutine.status(task._coro)

   if not resume_status then
      util.assert(coro_status == 'dead', generic_assert_message)
      self:_on_task_errored(task, resume_result)
   end

   if coro_status == 'dead' then
      _log("Detected task [%s] coroutine as dead", task._debug_task_tree)
      self:_discard_task(task)
   else
      if resume_result == _TASK_PAUSE then
         _log("Pausing task [%s]", task._debug_task_tree)
      else
         self:_schedule_task(task, resume_result)
      end

      if not util.map_is_empty(task._pending_cancellation_errors) then
         task:_consider_scheduling_for_pending_errors()
      end
   end
end

function lusc._Runner:_create_nursery(opts)
   opts = opts or {}

   local current_task = self:_get_running_task()
   local current_nursery = current_task:_try_get_current_nursery()

   if not opts.shielded and current_nursery ~= nil and current_nursery.cancel_scope._has_cancelled then
      error(current_nursery.cancel_scope._cancel_error)
   end

   local nursery = lusc.Nursery.new(self, current_task, opts)
   nursery:initialize()
   return nursery
end

function lusc._Runner:_run_nursery(handler, opts)
   util.assert(self._is_within_task_loop, "[lusc] Cannot run nursery outside of task loop")
   return self:_create_nursery(opts):_run(handler)
end

function lusc._Runner:_unschedule_task(task)
   util.assert(task._is_scheduled, generic_assert_message)
   local index = self:_find_task_index(task)
   util.assert(self._task_queue[index] == task, generic_assert_message)
   table.remove(self._task_queue, index)
   task._is_scheduled = false
end

function lusc._Runner:_process_tasks()
   util.assert(self._is_within_task_loop, generic_assert_message)
   local task_queue = self._task_queue

   while #task_queue > 0 do
      local time_to_wait = self:_try_get_time_to_next_task()

      if time_to_wait == nil or time_to_wait > 0 then
         _log("%.4f seconds to wait for next task, will reschedule event loop", time_to_wait)

         break
      end

      util.assert(not self._root_error, generic_assert_message)


      local current_time = _get_time()
      local pending_error_tasks_to_run = {}
      local tasks_to_run = {}





      while #task_queue > 0 and task_queue[#task_queue]._wait_until - current_time <= 0 do
         local task = table.remove(task_queue)
         _log("Removed task [%s] from run queue", task._debug_task_tree)
         util.assert(not task._done.is_set, generic_assert_message)
         util.assert(task._is_scheduled, generic_assert_message)
         task._is_scheduled = false

         if task:_has_pending_errors() then


            table.insert(pending_error_tasks_to_run, task)
         else
            table.insert(tasks_to_run, task)
         end
      end

      for _, task in ipairs(pending_error_tasks_to_run) do
         self:_run_task(task)
      end

      for _, task in ipairs(tasks_to_run) do
         self:_run_task(task)
      end
   end
end

function lusc._Runner:_get_root_nursery()
   return self._main_nursery
end

function lusc._Runner:_cancel_all()
   self._main_nursery.cancel_scope:cancel()
end

function lusc._Runner:_stop_requested()
   return self._stop_requested_event.is_set
end

function lusc._Runner:_stop(opts)
   util.assert(self._has_started, generic_assert_message)

   opts = opts or {}

   if opts.on_completed then
      table.insert(self._on_completed_handlers, opts.on_completed)
   end

   if self._has_stopped then
      util.assert(self._stop_requested_event.is_set, generic_assert_message)
      _log("Received request for stop() but stop has already completed")
      return
   end

   if self._stop_requested_event.is_set then
      _log("Received request for stop() but stop is already in progress (possibly due to an error)")
   else
      _log("Received request for stop().  Will end once tasks complete")
      util.assert(not self._has_stopped, generic_assert_message)



      self._stop_requested_event:set()
   end

   local deadline_opts = {
      move_on_after = opts.move_on_after,
      move_on_at = opts.move_on_at,
      fail_after = opts.fail_after,
      fail_at = opts.fail_at,
   }

   if self._main_nursery == nil then
      self._main_nursery_deadline_opts = deadline_opts
   else

      self._main_nursery.cancel_scope:_set_deadline(deadline_opts)
   end

   for func, _ in pairs(self._stop_requested_observers) do
      func()
   end
end

function lusc._Runner:_schedule(handler, opts)
   self:_check_errored()
   util.assert(self._has_started, generic_assert_message)


   if self._main_nursery == nil then
      table.insert(self._initial_handlers, { handler, opts })
   else

      self._main_nursery:start_soon(handler, opts)
   end
end

function lusc._Runner:_step()
   util.assert(not self._is_within_task_loop, generic_assert_message)
   self._is_within_task_loop = true
   self:_process_tasks()
   util.assert(self._is_within_task_loop, generic_assert_message)
   self._is_within_task_loop = false

   if self._root_error then
      util.assert(self._stop_requested_event.is_set, generic_assert_message)
   end

   local time_to_wait = self:_try_get_time_to_next_task()

   if time_to_wait == nil then


      if self._stop_requested_event.is_set then
         if util.map_is_empty(self._tasks_by_coro) then
            util.assert(#self._task_queue == 0, generic_assert_message)
            util.assert(self._main_task._done.is_set, generic_assert_message)
            self._main_task = nil
            self._main_nursery = nil
            util.assert(not self._has_stopped, generic_assert_message)
            self._has_stopped = true
            self._scheduler:dispose()

            for _, on_completed in ipairs(self._on_completed_handlers) do
               on_completed(self._root_error)
            end
         else
            _log("Stop requested but tasks have not completed, despite task queue being empty.  One explanation is that we are waiting to be woken up by another luv process")
         end
      else
         _log("No more tasks ready in queue, and no next time found. Will wait to be woken up by another event or new task schedule")
      end
   else
      self:_enqueue_step_in(math.max(0, time_to_wait))
   end
end

function lusc._Runner:_open_channel(max_buffer_size)
   local impl = ChannelImpl.new(self, max_buffer_size)
   return impl
end

function lusc._Runner:_new_sticky_event()
   self:_check_errored()
   return lusc.StickyEvent.new(self)
end

function lusc._Runner:_new_pulse_event()
   self:_check_errored()
   return lusc.PulseEvent.new(self)
end

function lusc._Runner:_cancel_scope(handler, opts)
   util.assert(self._is_within_task_loop, generic_assert_message)
   local task = self:_get_running_task()
   return lusc.CancelScope.new(self, task, opts):_run(handler)
end

function lusc._Runner:_start()
   util.assert(not self._has_started, generic_assert_message)
   util.assert(self._main_task == nil, generic_assert_message)
   util.assert(self._main_nursery == nil, generic_assert_message)
   util.assert(self._stop_requested_event == nil, generic_assert_message)
   util.assert(not self._is_within_task_loop, generic_assert_message)

   self._stop_requested_event = lusc.StickyEvent.new(self)

   self._main_task = self:_create_new_task_and_schedule(function()
      self:_run_nursery(function(nursery)
         util.assert(self._main_nursery == nil, generic_assert_message)
         self._main_nursery = nursery

         if self._main_nursery_deadline_opts ~= nil then
            nursery.cancel_scope:_set_deadline(self._main_nursery_deadline_opts)
         end

         for _, info in ipairs(self._initial_handlers) do
            nursery:start_soon(info[1], info[2])
         end
         self._initial_handlers = {}
         self._stop_requested_event:await()
      end, { name = "n-main" })
   end, nil, nil, { name = "t-main" })

   self._has_started = true
end



function lusc._get_runner()
   util.assert(not lusc._force_unavailable, generic_assert_message)
   local result = lusc._current_runner
   util.assert(result ~= nil, "[lusc] Attempted to use lusc but it has not been started")
   return result
end

function lusc.open_nursery(handler, opts)
   return lusc._get_runner():_run_nursery(handler, opts)
end


function lusc.get_time()
   return _get_time()
end

function lusc.try_get_async_local(key)
   return lusc._get_runner():_try_get_async_local(key)
end

function lusc.set_async_local(key, value)
   lusc._get_runner():_set_async_local(key, value)
end

function lusc.await_sleep(seconds)
   lusc._get_runner():_await_sleep(seconds)
end

function lusc.await_until(until_time)
   lusc._get_runner():_await_until(until_time)
end

function lusc.await_forever()
   lusc.await_until(math.huge)
end

function lusc.new_sticky_event()
   return lusc._get_runner():_new_sticky_event()
end

function lusc.new_pulse_event()
   return lusc._get_runner():_new_pulse_event()
end

function lusc.get_running_task()
   return lusc._get_runner():_get_running_task()
end

function lusc.try_get_running_task()
   return lusc._get_runner():_try_get_running_task()
end

function lusc.open_channel(max_buffer_size)
   return lusc._get_runner():_open_channel(max_buffer_size)
end

function lusc.schedule(handler, opts)
   lusc._get_runner():_schedule(handler, opts)
end

function lusc.schedule_wrap(handler, opts)
   return function(...)
      local args = { ... }
      lusc._get_runner():_schedule(function()
         handler(_tl_table_unpack(args))
      end, opts)
   end
end

function lusc.stop_requested()
   return lusc._get_runner():_stop_requested()
end

function lusc.set_log_handler(log_handler)
   util.set_log_handler(log_handler)
end

function lusc.stop(opts)
   lusc._get_runner():_stop(opts)
end

function lusc.cancel_all()
   lusc._get_runner():_cancel_all()
end

function lusc.has_started()
   return lusc._current_runner ~= nil
end

function lusc.is_available()
   return not lusc._force_unavailable and lusc._current_runner ~= nil and lusc._current_runner._is_within_task_loop
end

function lusc.force_unavailable(handler)
   if lusc._force_unavailable then
      return handler()
   end

   lusc._force_unavailable = true
   return util.try({
      action = handler,
      finally = function()
         util.assert(lusc._force_unavailable, generic_assert_message)
         lusc._force_unavailable = false
      end,
   })
end

function lusc.force_unavailable_wrap(handler)
   return function() return lusc.force_unavailable(handler) end
end

function lusc.get_root_nursery()
   return lusc._get_runner():_get_root_nursery()
end

function lusc.is_cancelled_error(err)
   return lusc._get_runner():_is_cancelled_error(err)
end

function lusc.cancel_scope(handler, opts)
   return lusc._get_runner():_cancel_scope(handler, opts)
end

function lusc.subscribe_stop_requested(observer)
   lusc._get_runner():_subscribe_stop_requested(observer)
end

function lusc.unsubscribe_stop_requested(observer)
   lusc._get_runner():_unsubscribe_stop_requested(observer)
end

function lusc.move_on_after(delay_seconds, handler, opts)
   opts = opts or {}
   return lusc.cancel_scope(handler, { move_on_after = delay_seconds, shielded = opts.shielded, name = opts.name })
end

function lusc.move_on_at(delay_seconds, handler, opts)
   opts = opts or {}
   return lusc.cancel_scope(handler, { move_on_at = delay_seconds, shielded = opts.shielded, name = opts.name })
end

function lusc.fail_after(delay_seconds, handler, opts)
   opts = opts or {}
   return lusc.cancel_scope(handler, { fail_after = delay_seconds, shielded = opts.shielded, name = opts.name })
end

function lusc.fail_at(delay_seconds, handler, opts)
   opts = opts or {}
   return lusc.cancel_scope(handler, { fail_at = delay_seconds, shielded = opts.shielded, name = opts.name })
end

function lusc.start(opts)
   util.assert(not lusc._force_unavailable, generic_assert_message)
   opts = opts or {}
   util.assert(opts.on_completed ~= nil, generic_assert_message)

   local new_opts = util.shallow_clone(opts)
   new_opts.on_completed = function(root_error)
      util.assert(lusc._current_runner ~= nil, generic_assert_message)
      lusc._current_runner = nil

      if opts.on_completed then
         opts.on_completed(root_error)
      elseif root_error ~= nil then
         _log("Aborted lusc due to error:\n%s", { root_error })
      end
   end

   util.assert(lusc._current_runner == nil, "Cannot call lusc.run from within another lusc.run")
   lusc._current_runner = lusc._Runner.new(new_opts)
   lusc._current_runner:_start()
end

return lusc
