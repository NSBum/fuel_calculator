#!/usr/bin/env lua

local script_dir = arg[0]:match("(.*/)")
if script_dir == nil or script_dir == "" then
    script_dir = "./"
end

package.path = script_dir .. "../lib/?.lua;" .. package.path

local core = require("core")

local passed = 0
local failed = 0

local function near(actual, expected, tolerance)
    tolerance = tolerance or 0.01
    return math.abs(actual - expected) <= tolerance
end

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("PASS: " .. name)
    else
        failed = failed + 1
        print("FAIL: " .. name)
        print("      " .. tostring(err))
    end
end

test("round_up_to_nearest_10 keeps exact multiples", function()
    assert(core.round_up_to_nearest_10(2410) == 2410)
end)

test("round_up_to_nearest_10 rounds up fractional values", function()
    assert(core.round_up_to_nearest_10(2400.59) == 2410)
    assert(core.round_up_to_nearest_10(633.7) == 640)
end)

local uplift_cases = {
    { label = "0%",  uplift = 0.00, required_lb = 13504.00, add_lb = 2714.00, litres = 1503.11 },
    { label = "10%", uplift = 0.10, required_lb = 14854.40, add_lb = 4064.40, litres = 2251.01 },
    { label = "12%", uplift = 0.12, required_lb = 15124.48, add_lb = 4334.48, litres = 2400.59 },
    { label = "15%", uplift = 0.15, required_lb = 15529.60, add_lb = 4739.60, litres = 2624.97 },
}

for _, case in ipairs(uplift_cases) do
    test("calculate litres with " .. case.label .. " uplift", function()
        local result = core.calculate(13504, 10790, case.uplift, "L", 0.819)
        assert(result ~= nil)
        assert(near(result.required_with_uplift_lb, case.required_lb))
        assert(near(result.fuel_to_add_lb, case.add_lb))
        assert(near(result.volume_to_add, case.litres, 0.1))
    end)
end

test("calculate US gallons in imperial units", function()
    local result = core.calculate(13504, 10790, 0.12, "USG", 6.84)
    assert(result ~= nil)
    assert(near(result.fuel_to_add_lb, 4334.48))
    assert(near(result.volume_to_add, 633.7, 0.1))
end)

test("calculate clamps uplift to zero when onboard exceeds required fuel", function()
    local result = core.calculate(6000, 7000, 0.12, "L", 0.819)
    assert(result ~= nil)
    assert(result.fuel_to_add_lb == 0)
    assert(result.volume_to_add == 0)
end)

test("calculate rejects negative trip fuel", function()
    local result, err = core.calculate(-1, 0, 0, "L", 0.819)
    assert(result == nil)
    assert(err == "Trip fuel cannot be negative.")
end)

test("calculate rejects zero density", function()
    local result, err = core.calculate(6000, 0, 0, "L", 0)
    assert(result == nil)
    assert(err == "Density in kg/L must be greater than zero.")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
