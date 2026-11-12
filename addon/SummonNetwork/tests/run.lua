-- Run from addon/SummonNetwork:  lua tests/run.lua
local files = { "tests/test_basic.lua", "tests/test_network.lua", "tests/smoke_wow.lua" }
local total_pass, total_fail = 0, 0
for _, f in ipairs(files) do
    print("##### " .. f)
    local L = dofile("tests/lib.lua")
    -- each test file builds its own harness; share counters through a package-level table
    package.loaded.__SN_TEST = nil
    local ok, res = pcall(dofile, f)
    if not ok then
        print("ERROR in " .. f .. ": " .. tostring(res))
        total_fail = total_fail + 1
    else
        total_pass = total_pass + res.pass
        total_fail = total_fail + res.fail
    end
end
print(string.format("\n%d checks passed, %d failed", total_pass, total_fail))
os.exit(total_fail == 0 and 0 or 1)
