local root = assert(os.getenv("DG_ROOT"))
local path = root .. "/mods/Darktide_Greyscale/scripts/mods/Darktide_Greyscale/"
local checks, warnings, writes, native_calls = 0, 0, 0, 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local hooks, safe, values = {}, {}, {enabled = false, desaturation = 90}
local mod = {}
function mod:get(key) return values[key] end
function mod:is_enabled() return true end
function mod:hook(object, method, callback)
    check(object == "CameraManager", "gameplay camera target")
    hooks[method] = callback
end
function mod:hook_safe(object, method, callback) safe[method] = callback end
function mod:warning() warnings = warnings + 1 end
get_mod = function(name) check(name == "Darktide_Greyscale", "correct mod ID"); return mod end
Vector3 = function(x, y, z) return {x = x, y = y, z = z} end
Viewport = {get_data = function(v, key) return v[key] end}
local allowed = {grey_scale_enabled = true, grey_scale_amount = true, grey_scale_weights = true}
local throw_once
ShadingEnvironment = {
    scalar = function(env, key) assert(not env.dead); return env[key] end,
    vector3 = function(env, key) assert(not env.dead); return env[key] end,
    set_scalar = function(env, key, value)
        assert(not env.dead); assert(allowed[key]); writes = writes + 1
        if throw_once == key then throw_once = nil; error("mock transient setter failure") end
        env[key] = value
    end,
    set_vector3 = function(env, key, value)
        assert(not env.dead); assert(allowed[key]); writes = writes + 1; env[key] = value
    end,
}
local function environment()
    return {grey_scale_enabled = 0, grey_scale_amount = 0.17,
        grey_scale_weights = Vector3(0.2, 0.7, 0.1), exposure = 2}
end
local world, viewport, env = {}, {name = "player1"}, environment()
local camera = {_world = world, _viewport_camera_data = {[viewport] = {}}}
Managers = {state = {camera = camera}}
local function native(self, w, e, v, resource)
    native_calls = native_calls + 1
    check(self == camera and w == world and e == env and v == viewport and resource == "resource",
        "original arguments preserved")
    check(e.grey_scale_enabled == 0 and e.grey_scale_amount == 0.17,
        "native must never receive previous mod override")
    check(e.grey_scale_weights.x == 0.2, "weights restored before original")
    -- Deliberately leave greyscale untouched, simulating a blend mask without it.
    e.exposure = 3
    return "native", nil, 9
end
local function invoke(fn)
    return hooks.shading_callback(fn or native, camera, world, env, viewport, "resource")
end
local function setting(key, value) values[key] = value; mod.on_setting_changed(key) end
dofile(path .. "Darktide_Greyscale.lua")
local a,b,c = invoke()
check(a == "native" and b == nil and c == 9, "return values including nil retained")
check(writes == 0, "default off has zero writes")
setting("enabled", true)
for _, percent in ipairs({0, 50, 80, 90, 100}) do
    setting("desaturation", percent)
    invoke()
    check(env.grey_scale_amount == (percent == 0 and 0.17 or percent / 100), "requested amount")
    check(env.grey_scale_enabled == (percent == 0 and 0 or 1), "enabled flag")
    check(env.exposure == 3, "unrelated native exposure intact")
    if percent > 0 then check(env.grey_scale_weights.x == 0.33, "native reference weights") end
    invoke() -- tests repeated callbacks with no native greyscale reset
end
setting("enabled", false)
check(env.grey_scale_enabled == 0 and env.grey_scale_amount == 0.17, "toggle restores immediately")
check(env.grey_scale_weights.y == 0.7, "native weights restored")
local count = writes; invoke(); check(writes == count, "off performs no writes")
setting("enabled", true); invoke(); mod.on_disabled()
check(env.grey_scale_enabled == 0 and env.grey_scale_weights.z == 0.1, "DMF disable cleanup")
invoke(); check(env.grey_scale_enabled == 0, "disabled stays inactive")
mod.on_enabled(); invoke(); mod.on_unload(); check(env.grey_scale_enabled == 0, "unload cleanup")
mod.on_enabled()
for _, bad in ipairs({-5, 105, math.huge, 0/0}) do
    setting("desaturation", bad); invoke()
    local expected = bad < 0 and 0.17 or bad == 105 and 1 or 0.9
    check(env.grey_scale_amount == expected, "clamp or default invalid values")
end
setting("enabled", false)
-- Invalid ownership and loading/shutdown states: original still called once.
setting("enabled", true)
local function noop() native_calls = native_calls + 1 end
for _, change in ipairs({"world", "manager", "viewport", "nil_env"}) do
    local prior = writes
    if change == "world" then camera._world = {} end
    if change == "manager" then Managers.state.camera = {} end
    if change == "viewport" then camera._viewport_camera_data = {} end
    if change == "nil_env" then
        hooks.shading_callback(noop, camera, world, nil, viewport, "resource")
    else invoke(noop) end
    check(writes == prior, "invalid state must not write: " .. change)
    camera._world = world; Managers.state.camera = camera; camera._viewport_camera_data = {[viewport] = {}}
end
-- A menu camera is rejected even if it has the same structural fields.
local menu = {_world = world, _viewport_camera_data = {[viewport] = {}}}
count = writes; hooks.shading_callback(noop, menu, world, env, viewport, "resource")
check(writes == count, "UI/menu camera untouched")
-- Missing engine API fails closed, warns once, and never writes.
local getter = ShadingEnvironment.vector3; ShadingEnvironment.vector3 = nil
invoke(); invoke(); check(warnings == 1, "missing getter warning once")
ShadingEnvironment.vector3 = getter
mod.on_setting_changed(); invoke(); check(env.grey_scale_enabled == 1, "retry after settings change")
-- Partial write errors restore all three captured parameters.
mod.on_setting_changed(); throw_once = "grey_scale_amount"; invoke()
check(env.grey_scale_enabled == 0 and env.grey_scale_weights.y == 0.7, "partial write rollback")
check(warnings == 2, "one additional failure warning")
mod.on_setting_changed(); invoke()
mod.on_game_state_changed("exit", "StateGameplay")
check(env.grey_scale_enabled == 0, "gameplay exit restores")
-- Capture changing native moods, rather than a startup-only snapshot.
invoke(function()
    env.grey_scale_enabled, env.grey_scale_amount = 1, 0.4
    env.grey_scale_weights = Vector3(0.1, 0.3, 0.6)
end)
mod.on_disabled()
check(env.grey_scale_enabled == 1 and env.grey_scale_amount == 0.4
    and env.grey_scale_weights.z == 0.6, "native mood values restored exactly")
env.grey_scale_enabled, env.grey_scale_amount = 0, 0.17
env.grey_scale_weights = Vector3(0.2, 0.7, 0.1)
mod.on_enabled()
-- Separate viewport snapshots; destroying one must not discard the other's restoration.
local second_view = {name = "player2"}
local second_env = environment()
camera._viewport_camera_data[second_view] = {}
invoke()
hooks.shading_callback(noop, camera, world, second_env, second_view, "resource")
env.dead = true; camera._viewport_camera_data[viewport] = nil
safe.destroy_viewport(camera, "player1")
mod.on_disabled()
check(second_env.grey_scale_amount == 0.17 and second_env.grey_scale_weights.y == 0.7,
    "other viewport still restored after teardown")
env = environment(); camera._viewport_camera_data[viewport] = {}; mod.on_enabled()
-- Destroyed resources must never be accessed during cleanup.
invoke(); env.dead = true; camera._viewport_camera_data = {}
safe.destroy_viewport(camera, "player1"); mod.on_disabled()
check(warnings == 2, "teardown causes no errors")
env = environment(); camera._viewport_camera_data = {[viewport] = {}}
-- Native failures remain native failures: never call original twice.
mod.on_enabled(); local n = 0
local ok = pcall(function() invoke(function() n = n + 1; error("native failure") end) end)
check(not ok and n == 1, "native exception unchanged")
local data = dofile(path .. "Darktide_Greyscale_data.lua")
local loc = dofile(path .. "Darktide_Greyscale_localization.lua")
check(data.is_togglable and #data.options.widgets == 2, "two settings with DMF toggling")
local enable, slider = unpack(data.options.widgets)
check(enable.default_value == false and enable.type == "checkbox", "off by default")
check(slider.default_value == 90 and slider.range[1] == 0 and slider.range[2] == 100
    and slider.step_size_value == 5 and slider.decimals_number == 0, "slider definition")
check(loc[enable.setting_id].en and loc[slider.setting_id].en, "localization keys")
-- DMF formats localized strings, even when no substitution args are supplied.
check(not pcall(string.format, "Desaturation (%)"), "old label reproduces format failure")
check(loc.desaturation.en == "Desaturation", "plain robust visible label")
for key, translations in pairs(loc) do
    check(pcall(string.format, translations.en), "localization formats safely: " .. key)
end
local registered
new_mod = function(id, registration) registered = registration; check(id == "Darktide_Greyscale", "manifest ID") end
fassert = assert
local manifest = dofile(root .. "/mods/Darktide_Greyscale/Darktide_Greyscale.mod")
manifest.run()
for _, key in ipairs({"mod_script", "mod_data", "mod_localization"}) do
    check(loadfile(root .. "/mods/" .. registered[key] .. ".lua") ~= nil, "manifest path: " .. key)
end
print(string.format("PASS: %d assertions; native calls %d; controlled warnings %d", checks, native_calls, warnings))
