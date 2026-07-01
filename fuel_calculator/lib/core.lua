local M = {}

M.LB_TO_KG = 0.45359237

function M.round_up_to_nearest_10(x)
    return math.ceil(x / 10) * 10
end

function M.calculate(trip_lb, onboard_lb, uplift_percent, volume_unit, density)
    if trip_lb == nil then
        return nil, "Trip fuel must be a number."
    end

    if onboard_lb == nil then
        return nil, "Fuel on board must be a number."
    end

    if density == nil then
        if volume_unit == "USG" then
            return nil, "Density must be a number in lb/USG."
        end
        return nil, "Density must be a number in kg/L."
    end

    if trip_lb < 0 then
        return nil, "Trip fuel cannot be negative."
    end

    if onboard_lb < 0 then
        return nil, "Fuel on board cannot be negative."
    end

    if density <= 0 then
        if volume_unit == "USG" then
            return nil, "Density in lb/USG must be greater than zero."
        end
        return nil, "Density in kg/L must be greater than zero."
    end

    local uplift_factor = 1.0 + uplift_percent
    local required_with_uplift_lb = trip_lb * uplift_factor
    local fuel_to_add_lb = required_with_uplift_lb - onboard_lb

    if fuel_to_add_lb < 0 then
        fuel_to_add_lb = 0
    end

    local volume_to_add
    if volume_unit == "USG" then
        volume_to_add = fuel_to_add_lb / density
    else
        local fuel_to_add_kg = fuel_to_add_lb * M.LB_TO_KG
        volume_to_add = fuel_to_add_kg / density
    end

    return {
        required_with_uplift_lb = required_with_uplift_lb,
        fuel_to_add_lb = fuel_to_add_lb,
        volume_to_add = volume_to_add,
    }
end

return M
