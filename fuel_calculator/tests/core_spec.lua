package.path = arg[0]:match("(.*/)") .. "../lib/?.lua;" .. package.path
local core = require("core")

local function near(actual, expected, tolerance)
    tolerance = tolerance or 0.01
    return math.abs(actual - expected) <= tolerance
end

describe("fuel_calculator core", function()
    describe("round_up_to_nearest_10", function()
        it("rounds exact multiples unchanged", function()
            assert.are.equal(2410, core.round_up_to_nearest_10(2410))
        end)

        it("rounds up fractional values", function()
            assert.are.equal(2410, core.round_up_to_nearest_10(2400.59))
            assert.are.equal(640, core.round_up_to_nearest_10(633.7))
        end)

        it("rounds up exact tens boundaries", function()
            assert.are.equal(1620, core.round_up_to_nearest_10(1610.23))
        end)
    end)

    describe("calculate", function()
        local uplift_cases = {
            { label = "0%",  uplift = 0.00, required_lb = 13504.00, add_lb = 2714.00, litres = 1503.11 },
            { label = "10%", uplift = 0.10, required_lb = 14854.40, add_lb = 4064.40, litres = 2251.01 },
            { label = "12%", uplift = 0.12, required_lb = 15124.48, add_lb = 4334.48, litres = 2400.59 },
            { label = "15%", uplift = 0.15, required_lb = 15529.60, add_lb = 4739.60, litres = 2624.97 },
        }

        for _, case in ipairs(uplift_cases) do
            it("computes litres with " .. case.label .. " uplift", function()
                local result = core.calculate(13504, 10790, case.uplift, "L", 0.819)

                assert.is_not_nil(result)
                assert.is_true(near(result.required_with_uplift_lb, case.required_lb))
                assert.is_true(near(result.fuel_to_add_lb, case.add_lb))
                assert.is_true(near(result.volume_to_add, case.litres, 0.1))
            end)
        end

        it("computes US gallons in imperial units", function()
            local result = core.calculate(13504, 10790, 0.12, "USG", 6.84)

            assert.is_not_nil(result)
            assert.is_true(near(result.fuel_to_add_lb, 4334.48))
            assert.is_true(near(result.volume_to_add, 633.7, 0.1))
        end)

        it("clamps uplift to zero when onboard exceeds required fuel", function()
            local result = core.calculate(6000, 7000, 0.12, "L", 0.819)

            assert.is_not_nil(result)
            assert.are.equal(0, result.fuel_to_add_lb)
            assert.are.equal(0, result.volume_to_add)
        end)

        it("rejects negative trip fuel", function()
            local result, err = core.calculate(-1, 0, 0, "L", 0.819)

            assert.is_nil(result)
            assert.are.equal("Trip fuel cannot be negative.", err)
        end)

        it("rejects zero density", function()
            local result, err = core.calculate(6000, 0, 0, "L", 0)

            assert.is_nil(result)
            assert.are.equal("Density in kg/L must be greater than zero.", err)
        end)
    end)
end)
