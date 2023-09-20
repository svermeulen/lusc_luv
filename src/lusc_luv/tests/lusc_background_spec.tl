
require("busted")

local lusc <const> = require('lusc')
local util <const> = require('lusc.util')
local lusc_luv <const> = require("lusc_luv")

local test_time_interval = 0.05

describe("lusc background", function()
   it("simple sleep", function()
      local start_time = lusc_luv.get_time()
      local runner = lusc_luv.run_in_background({
         generate_debug_names = true,
      })
      runner:schedule(function()
         lusc.await_sleep(test_time_interval)
      end)
      runner:wait()
      runner:dispose()
      local elapsed = lusc_luv.get_time() - start_time
      util.assert(elapsed > test_time_interval and elapsed < 2 * test_time_interval, "Found %s seconds elapsed but expected %s", elapsed, test_time_interval)
   end)
end)
