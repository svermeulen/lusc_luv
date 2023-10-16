local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table
require("busted")

local test_async_helper = require("lusc.tests.async_helper")
local util = require("lusc.internal.util")
local luv_async = require("lusc.luv_async")
local uv = require("luv")

local default_dir_permissions = tonumber('755', 8)
local default_file_permissions = 438

local function _path_exists(path)
   local stats = uv.fs_stat(path)
   return stats ~= nil
end

local function _is_directory(path)
   local stats = uv.fs_stat(path)
   return stats ~= nil and stats.type == "directory"
end

local function get_local_timestamp_seconds()
   local results = uv.clock_gettime("realtime")
   return results.sec + (results.nsec / 1e9)
end

local function _create_directory(path)
   assert(uv.fs_mkdir(path, default_dir_permissions))
end

local function _create_temp_directory()
   local root_temp_dir = assert(uv.os_tmpdir())
   assert(root_temp_dir ~= nil and #root_temp_dir > 0)

   util.assert(_is_directory(root_temp_dir))

   local temp_dir
   local max_attempts = 5
   local num_attempts = 0

   while true do
      num_attempts = num_attempts + 1
      temp_dir = root_temp_dir .. "/lusc_" .. tostring(math.floor(100000000 * math.random()))

      if not _is_directory(temp_dir) then
         break
      end

      util.assert(num_attempts < max_attempts)


      util.log("Found unexpected duplicate temporary directory at '%s'.  Trying again...", temp_dir)
   end

   _create_directory(temp_dir)
   util.assert(_is_directory(temp_dir))
   return temp_dir
end

describe("luv_async", function()
   local temp_dir = nil

   before_each(function()
      temp_dir = _create_temp_directory()
      util.log("Created temp directory at '%s'", temp_dir)
   end)

   after_each(function()
      util.log("Deleting temp directory at '%s'", temp_dir)
      util.assert(_path_exists(temp_dir) and _is_directory(temp_dir))


      temp_dir = nil
   end)

   local function await_is_directory(path)
      local stats = luv_async.try_await_stat(path)
      return stats ~= nil and stats.type == "directory"
   end

   local function await_is_file(path)
      local stats = luv_async.try_await_stat(path)
      return stats ~= nil and stats.type == "file"
   end

   local function await_path_exists(path)
      local stats = luv_async.try_await_stat(path)
      return stats ~= nil
   end

   local function create_directory(path)
      local success, err = uv.fs_mkdir(path, default_dir_permissions)
      if not success then
         error(string.format("Failed to create directory '%s': %s", path, err))
      end
   end

   local function await_delete_empty_directory(path)
      local success, error_message = pcall(luv_async.await_rmdir, path)
      if not success then
         error(string.format("Failed to remove directory at '%s'. Details: %s", path, error_message))
      end
   end

   local function await_get_sub_paths(path)
      local names = {}



      local page_size = 256

      local dir = luv_async.await_opendir(path, page_size)
      util.try({
         action = function()
            local paths = dir:await_readdir()
            while #paths > 0 do
               for _, info in ipairs(paths) do
                  table.insert(names, info.name)
               end
               paths = dir:await_readdir()
            end
         end,
         finally = function()
            dir:await_closedir()
         end,
      })
      return names
   end

   local function await_get_last_modified_time_seconds(path)
      local stats = assert(luv_async.await_stat(path))
      return stats.mtime.sec + (stats.mtime.nsec / 1e9)
   end

   local function await_write_file(path, contents)
      local fd = luv_async.await_open(path, "w", default_file_permissions)
      util.try({
         action = function()
            luv_async.await_write(fd, contents, 0)
            luv_async.await_close(fd)
         end,
         catch = function(err)
            assert(uv.fs_close(fd))
            error(err)
         end,
      })
   end

   local function await_read_file(path)
      local fd = luv_async.await_open(path, "r", default_file_permissions)
      return util.try({
         action = function()
            local stat = luv_async.await_fstat(fd)
            local data = luv_async.await_read(fd, stat.size, 0)
            luv_async.await_close(fd)
            return data
         end,
         catch = function(err)
            assert(uv.fs_close(fd))
            error(err)
         end,
      })
   end

   local function await_append_file(path, contents)
      local fd = luv_async.await_open(path, "a", default_file_permissions)
      util.try({
         action = function()

            luv_async.await_write(fd, contents, -1)
            luv_async.await_close(fd)
         end,
         catch = function(err)
            assert(uv.fs_close(fd))
            error(err)
         end,
      })
   end

   it("await_is_directory, await_is_file, await_path_exists", function()
      test_async_helper.run_lusc(function()
         util.assert(await_is_directory(temp_dir))
         util.assert(not await_is_file(temp_dir))
         util.assert(await_path_exists(temp_dir))
      end)
   end)

   it("await_delete_empty_directory", function()
      test_async_helper.run_lusc(function()
         local new_dir = temp_dir .. "/" .. "subdir"
         create_directory(new_dir)

         util.assert(_is_directory(new_dir))
         await_delete_empty_directory(new_dir)
         util.assert(not _is_directory(new_dir))
      end)
   end)

   it("await_get_sub_paths", function()
      test_async_helper.run_lusc(function()
         _create_directory(temp_dir .. "/subdir")
         await_write_file(temp_dir .. "/blurg.txt", "asdlfjzlxjv\nlasjlzx")
         await_write_file(temp_dir .. "/zeb.txt", "ljsdlfj")

         local result = await_get_sub_paths(temp_dir)
         util.assert(#result == 3)

         table.sort(result)
         util.assert(result[1] == "blurg.txt")
         util.assert(result[2] == "subdir")
         util.assert(result[3] == "zeb.txt")
      end)
   end)

   it("await_get_last_modified_time_seconds", function()
      test_async_helper.run_lusc(function()
         local temp_file = temp_dir .. "/blurg.txt"

         local current_time = get_local_timestamp_seconds()
         await_write_file(temp_file, "asdlfjzlxjv\nlasjlzx")

         local result = await_get_last_modified_time_seconds(temp_file)
         util.assert(math.abs(result - current_time) < 0.1)
      end)
   end)


   it("await read and write files", function()
      test_async_helper.run_lusc(function()
         local foo_path = temp_dir .. "/foo"
         local text1 = "foo1\nfoo2"
         await_write_file(foo_path, text1)
         local text2 = await_read_file(foo_path)
         util.assert(text1 == text2)
         local append_text = "blurg\nbar"
         local text3 = text1 .. append_text
         await_append_file(foo_path, append_text)
         local text4 = await_read_file(foo_path)
         util.assert(text3 == text4)
      end)
   end)
end)
