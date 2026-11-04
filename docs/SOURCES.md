# Source verification — 4 November 2026

Read-only source inspection; installed Fedora files were not accessed. These public revisions may differ from your installed game/framework.

- [scripts/managers/camera/camera_manager.lua](https://github.com/Aussiemon/Darktide-Source-Code/blob/e46b8926cfa3fa35503e4b80b15aab7a804314e4/scripts/managers/camera/camera_manager.lua) — SHA256 `210988ed10a0107d4c495f0852e908c83ffc82ed7fd2d02f62ee7fd36346fbfc`
- [scripts/managers/ui/ui_world_spawner.lua](https://github.com/Aussiemon/Darktide-Source-Code/blob/e46b8926cfa3fa35503e4b80b15aab7a804314e4/scripts/managers/ui/ui_world_spawner.lua) — SHA256 `545f06d897c59225f637f09a4045403b273ca04edfe831d8b11c445b75bb5846`
- [dmf/scripts/mods/dmf/modules/core/hooks.lua](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework/blob/0107475ee51f07af2957b72fdf09b83e0b114791/dmf/scripts/mods/dmf/modules/core/hooks.lua) — SHA256 `8f6439700ac6c6af9bce003122317bc37263509e061d7d67eb842d06e130da09`
- [dmf/scripts/mods/dmf/modules/core/events.lua](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework/blob/0107475ee51f07af2957b72fdf09b83e0b114791/dmf/scripts/mods/dmf/modules/core/events.lua) — SHA256 `244231f05b832bbb8c66fa67b15109c9f8d943213bf4a2c44282a8f0ffacff68`
- [dmf/scripts/mods/dmf/modules/core/toggling.lua](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework/blob/0107475ee51f07af2957b72fdf09b83e0b114791/dmf/scripts/mods/dmf/modules/core/toggling.lua) — SHA256 `fab007a3bf83e2a055cfbbf25c6f89c96f9bd5fcdf4dfe1ec9ab6e027f5144c4`
- [dmf/scripts/mods/dmf/modules/core/options.lua](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework/blob/0107475ee51f07af2957b72fdf09b83e0b114791/dmf/scripts/mods/dmf/modules/core/options.lua) — SHA256 `a874e2b13d8db44f541832999acafdaa278411682ec0d39739a742ab4614dbbe`
- [dmf/scripts/mods/dmf/modules/ui/options/mod_options.lua](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework/blob/0107475ee51f07af2957b72fdf09b83e0b114791/dmf/scripts/mods/dmf/modules/ui/options/mod_options.lua) — SHA256 `9807cbff16053e1dcfceb1a28fd9e37a93620c923b906b1efd5ffa87670db59f`

## Verified contracts

- Camera callback: `(self, world, shading_env, viewport, default_shading_environment_resource)`. Native code blends environment and mood lists using `ShadingEnvironment.ordered_blend`, then applies native per-camera controls. Both direct and overridden viewport camera data are accepted.
- UIWorldSpawner reference uses `set_scalar` for `grey_scale_enabled` and `grey_scale_amount` (clamped 0–1), and `set_vector3` with weights `(0.33, 0.33, 0.33)`. The mod borrows these parameter names but never hooks the UI callback.
- DMF `hook` receives the next function followed by original arguments. `hook_safe` runs after the normal hook chain using a protected framework call. One hook record is allowed per mod/target, so pre-restoration and protected post-work share a normal wrapper.
- String class hook targets can be delayed until their class/method is available. No forced game-file require is necessary.
- DMF toggle implementation disables hooks before `on_disabled`, so that event performs its own direct cleanup. `on_unload`, `on_game_state_changed`, `on_setting_changed`, and `on_settings_reset` are dispatched by core/events.lua.
- Numeric options accept `range`, `decimals_number`, `step_size_value` and default; mod_options rounds to the requested step.

## Additional engine API reference

[Autodesk Stingray ShadingEnvironment API](https://help.autodesk.com/cloudhelp/ENU/Stingray-Help/lua_ref/obj_stingray_ShadingEnvironment.html) documents `scalar`, `vector3`, `set_scalar`, and `set_vector3`. The Darktide Lua inspected uses the scalar getter and setters; no vector3 getter use was found in that public Lua snapshot. Runtime availability and parameter reads are checked before any override. Missing getter or rejected parameter produces a single suspension warning. This is an explicit unverified native-API dependency, not claimed in-game validation.
