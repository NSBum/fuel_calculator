-- Fuel Calculator for X-Plane 12 / FlyWithLua NG+

if not SUPPORTS_FLOATING_WINDOWS then
    logMsg("Fuel Calculator: floating windows are not supported by this FlyWithLua version.")
    return
end

local FUEL_CALC_DIR = SCRIPT_DIRECTORY .. "fuel_calculator" .. DIRECTORY_SEPARATOR

local function load_core()
    local core_path = FUEL_CALC_DIR .. "lib" .. DIRECTORY_SEPARATOR .. "core.lua"
    local chunk, load_err = loadfile(core_path)
    if chunk == nil then
        logMsg("Fuel Calculator: failed to load core module: " .. tostring(load_err))
        return nil
    end

    local ok, core = pcall(chunk)
    if not ok then
        logMsg("Fuel Calculator: failed to run core module: " .. tostring(core))
        return nil
    end

    return core
end

local core = load_core()

local win = nil

local trip_fuel_lb = "6000"
local onboard_fuel_lb = "0"
local density_kg_per_l = "0.819"
local density_lb_per_gal = "6.84"

local uplift_percent = 0
local uplift_options = {
    { label = "0%",  value = 0.00 },
    { label = "10%", value = 0.10 },
    { label = "12%", value = 0.12 },
    { label = "15%", value = 0.15 }
}

local volume_unit = "L"

local required_with_uplift_lb = nil
local fuel_to_add_lb = nil
local volume_to_add = nil
local error_message = ""

local function calculate_fuel_to_add()
    if core == nil then
        error_message = "Calculator core module is not loaded."
        required_with_uplift_lb = nil
        fuel_to_add_lb = nil
        volume_to_add = nil
        return
    end

    local trip_lb = tonumber(trip_fuel_lb)
    local onboard_lb = tonumber(onboard_fuel_lb)

    error_message = ""
    required_with_uplift_lb = nil
    fuel_to_add_lb = nil
    volume_to_add = nil

    local density
    if volume_unit == "USG" then
        density = tonumber(density_lb_per_gal)
    else
        density = tonumber(density_kg_per_l)
    end

    local result, calc_error = core.calculate(
        trip_lb,
        onboard_lb,
        uplift_percent,
        volume_unit,
        density
    )

    if result ~= nil then
        required_with_uplift_lb = result.required_with_uplift_lb
        fuel_to_add_lb = result.fuel_to_add_lb
        volume_to_add = result.volume_to_add
        error_message = ""
    else
        error_message = calc_error or "Calculation failed."
    end
end

function fuel_calculator_draw_window()
    if core == nil then
        imgui.TextUnformatted("Fuel Calculator failed to load.")
        imgui.TextUnformatted("Check FlyWithLua log for details.")
        return
    end

    imgui.TextUnformatted("Fuel Calculator")
    imgui.Separator()

    imgui.TextUnformatted("Fuel needed for trip, lb:")
    local changed_trip
    changed_trip, trip_fuel_lb = imgui.InputText("##fc_trip_fuel_lb", trip_fuel_lb, 32)

    imgui.TextUnformatted("Fuel currently on board, lb:")
    local changed_onboard
    changed_onboard, onboard_fuel_lb = imgui.InputText("##fc_onboard_fuel_lb", onboard_fuel_lb, 32)

    local changed_density = false
    if volume_unit == "USG" then
        imgui.TextUnformatted("Fuel density, lb/USG:")
        changed_density, density_lb_per_gal = imgui.InputText("##fc_density_lb_per_gal", density_lb_per_gal, 32)
    else
        imgui.TextUnformatted("Fuel density, kg/L:")
        changed_density, density_kg_per_l = imgui.InputText("##fc_density_kg_per_l", density_kg_per_l, 32)
    end

    imgui.Separator()
    imgui.TextUnformatted("Add reserve/uplift to trip fuel:")

    local changed_uplift = false

    for i, option in ipairs(uplift_options) do
        if i > 1 then
            imgui.SameLine()
        end

        local selected = math.abs(uplift_percent - option.value) < 0.0001
        local clicked
        clicked, selected = imgui.RadioButton(option.label, selected)

        if clicked then
            uplift_percent = option.value
            changed_uplift = true
        end
    end

    imgui.Separator()
    imgui.TextUnformatted("Volume unit for output:")

    local changed_unit = false

    local litres_selected = (volume_unit == "L")
    local clicked_l
    clicked_l, litres_selected = imgui.RadioButton("Litres", litres_selected)
    if clicked_l and volume_unit ~= "L" then
        volume_unit = "L"
        changed_unit = true
    end

    imgui.SameLine()

    local gallons_selected = (volume_unit == "USG")
    local clicked_g
    clicked_g, gallons_selected = imgui.RadioButton("US Gallons", gallons_selected)
    if clicked_g and volume_unit ~= "USG" then
        volume_unit = "USG"
        changed_unit = true
    end

    if imgui.Button("Calculate") or changed_trip or changed_onboard or changed_density or changed_uplift or changed_unit then
        calculate_fuel_to_add()
    end

    imgui.Separator()

    if error_message ~= "" then
        imgui.TextUnformatted(error_message)
    elseif volume_to_add ~= nil then
        imgui.TextUnformatted(string.format("Required trip fuel with uplift: %.0f lb", required_with_uplift_lb))
        imgui.TextUnformatted(string.format("Fuel to uplift: %.0f lb", fuel_to_add_lb))

        local rounded_volume_to_add = core.round_up_to_nearest_10(volume_to_add)
        if volume_unit == "USG" then
            imgui.TextUnformatted(string.format("US gallons to add: %.0f USG", rounded_volume_to_add))
            imgui.TextUnformatted(string.format("Exact US gallons: %.2f USG", volume_to_add))
        else
            imgui.TextUnformatted(string.format("Litres to add: %.0f L", rounded_volume_to_add))
            imgui.TextUnformatted(string.format("Exact litres: %.2f L", volume_to_add))
        end
    else
        imgui.TextUnformatted("Enter values and press Calculate.")
    end

    imgui.Separator()
    imgui.TextUnformatted("Formula:")
    if volume_unit == "USG" then
        imgui.TextUnformatted("(trip_lb * uplift - onboard_lb) / lb_per_USG")
    else
        imgui.TextUnformatted("(trip_lb * uplift - onboard_lb) * 0.45359237 / kg_per_L")
    end
end

function fuel_calculator_on_close(wnd)
    win = nil
end

function fuel_calculator_show_window()
    if win ~= nil then
        local ok, visible = pcall(float_wnd_get_visible, win)
        if ok and visible then
            return
        end
        win = nil
    end

    win = float_wnd_create(430, 400, 1, true)
    float_wnd_set_title(win, "Fuel Calculator")
    float_wnd_set_imgui_builder(win, fuel_calculator_draw_window)
    float_wnd_set_onclose(win, "fuel_calculator_on_close")
end

function fuel_calculator_hide_window()
    if win ~= nil then
        float_wnd_destroy(win)
        win = nil
    end
end

function fuel_calculator_toggle_window()
    if win ~= nil then
        local ok, visible = pcall(float_wnd_get_visible, win)
        if ok and visible then
            fuel_calculator_hide_window()
            return
        end
        win = nil
    end

    fuel_calculator_show_window()
end

add_macro("Fuel Calculator", "fuel_calculator_show_window()")

create_command(
    "FlyWithLua/fuel_calculator/toggle",
    "Toggle Fuel Calculator",
    "fuel_calculator_toggle_window()",
    "",
    ""
)

if core ~= nil then
    calculate_fuel_to_add()
end
