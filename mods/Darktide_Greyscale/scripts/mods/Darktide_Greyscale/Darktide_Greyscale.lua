local mod = get_mod("Darktide_Greyscale")
local active, amount = false, 0
local records = {} -- one reusable snapshot per live viewport, never stored frame vectors
local failed, warned = false, false
local toggled_on = mod:is_enabled()

local function finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end

local function valid(camera, world, env, viewport)
    if not camera or not world or not env or not viewport then return false end
    local state = Managers and Managers.state
    if not state or state.camera ~= camera or camera._world ~= world then return false end
    local data = camera._viewport_camera_data
    if not data then return false end
    -- Match native overridden-viewports handling; the active camera manager owns these.
    return data[viewport] ~= nil or
        (Viewport and data[Viewport.get_data(viewport, "overridden_viewport")] ~= nil)
end

local function restore(r)
    if not r.applied then return end
    if not valid(r.camera, r.world, r.env, r.viewport) then
        r.applied = false -- resource no longer owned/live: never dereference its environment
        return
    end
    ShadingEnvironment.set_vector3(r.env, "grey_scale_weights", Vector3(r.x, r.y, r.z))
    ShadingEnvironment.set_scalar(r.env, "grey_scale_amount", r.amount)
    ShadingEnvironment.set_scalar(r.env, "grey_scale_enabled", r.enabled)
    r.applied = false
end

local function restore_all()
    for viewport, r in pairs(records) do
        pcall(restore, r) -- stale engine handles must not break disable/unload
        records[viewport] = nil
    end
end

local function fail(message)
    failed = true
    restore_all()
    if not warned then
        warned = true
        mod:warning("Greyscale suspended until re-enabled: %s", tostring(message))
    end
end

local function refresh()
    local value = mod:get("desaturation")
    if not finite(value) then value = 90 end
    amount = math.max(0, math.min(100, value)) / 100
    active = toggled_on and mod:get("enabled") == true and amount > 0
end

local function before_native(camera, world, env, viewport)
    local r = records[viewport]
    if r then
        restore(r)
        if r.camera ~= camera or r.world ~= world or r.env ~= env then
            records[viewport] = nil
        end
    end
end

local function apply(camera, world, env, viewport)
    if not active or failed or not valid(camera, world, env, viewport) then return end
    local api = ShadingEnvironment
    -- vector3 is documented by the engine API, but runtime capability is checked:
    -- no write is made if a complete restorable snapshot cannot be obtained.
    if not api or type(api.scalar) ~= "function" or type(api.vector3) ~= "function"
        or type(api.set_scalar) ~= "function" or type(api.set_vector3) ~= "function" then
        error("required ShadingEnvironment getters/setters unavailable")
    end
    local enabled = api.scalar(env, "grey_scale_enabled")
    local native_amount = api.scalar(env, "grey_scale_amount")
    local weights = api.vector3(env, "grey_scale_weights")
    if not finite(enabled) or not finite(native_amount) or not weights
        or not finite(weights.x) or not finite(weights.y) or not finite(weights.z) then
        error("invalid native greyscale snapshot")
    end
    local r = records[viewport]
    if not r then
        r = {camera = camera, world = world, env = env, viewport = viewport,
            name = Viewport.get_data(viewport, "name")}
        records[viewport] = r
    end
    r.enabled, r.amount, r.x, r.y, r.z = enabled, native_amount, weights.x, weights.y, weights.z
    r.applied = true -- covers partial writes if a setter throws
    api.set_vector3(env, "grey_scale_weights", Vector3(0.33, 0.33, 0.33))
    api.set_scalar(env, "grey_scale_amount", amount)
    api.set_scalar(env, "grey_scale_enabled", 1)
end

-- Preserve every original return value (including nils), without a pack table.
local function after_native(camera, world, env, viewport, ...)
    local ok, err = pcall(apply, camera, world, env, viewport)
    if not ok then fail(err) end
    return ...
end

-- A normal hook is necessary for pre-blend restoration. DMF allows only one
-- hook type per mod/target. Both our pre/post work are protected independently;
-- the original callback is always called exactly once, with untouched arguments.
mod:hook("CameraManager", "shading_callback", function(next_call, camera, world, env, viewport, resource)
    if (not active or failed) and not next(records) then
        return next_call(camera, world, env, viewport, resource)
    end
    local ok, err = pcall(before_native, camera, world, env, viewport)
    if not ok then fail(err) end
    return after_native(camera, world, env, viewport,
        next_call(camera, world, env, viewport, resource))
end)

-- Native teardown has already destroyed resources: forget, do not touch them.
mod:hook_safe("CameraManager", "destroy_viewport", function(camera, viewport_name)
    for viewport, r in pairs(records) do
        if r.camera == camera and r.name == viewport_name then records[viewport] = nil end
    end
end)

mod.on_setting_changed = function()
    restore_all()
    failed, warned = false, false
    refresh()
end
mod.on_settings_reset = mod.on_setting_changed
mod.on_enabled = function()
    toggled_on = true
    mod.on_setting_changed()
end
mod.on_disabled = function()
    toggled_on, active = false, false
    restore_all() -- DMF disables hooks before dispatching this event
end
mod.on_unload = mod.on_disabled
mod.on_game_state_changed = function(status, state_name)
    if status == "exit" and state_name == "StateGameplay" then restore_all() end
end
refresh()
