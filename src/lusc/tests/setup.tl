
local util <const> = require('lusc.internal.util')

util.set_log_handler(function(message:string)
   print(message)
end)

math.randomseed(os.time())
-- After seeding, we need to pop off a few numbers to ensure
-- the first one actually is random
-- Otherwise you get a very similar first number
-- Taken from: https://stackoverflow.com/a/20157671/23213
math.random(); math.random(); math.random()
