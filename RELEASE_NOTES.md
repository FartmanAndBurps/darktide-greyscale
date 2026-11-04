Darktide Greyscale adds adjustable gameplay desaturation from 0–100% in 5% steps. The default amount is 90%; the effect defaults Off and can be changed in Mod Options during gameplay.

v0.1.1 fixes the startup localisation error caused by the old percent-sign label. The mod preserves native environment blending and restores its greyscale overrides when disabled or set to 0%.

Tested through full missions on Fedora Linux/Proton with Enemies Improved 3.0.8's coloured outlines. Enemies Improved is optional. Outline colours remained vivid in testing, but this mod does not selectively mask enemy outlines from greyscale; rendering interactions and compatibility across HDR/upscaler/frame-generation combinations are not fully established.

**Requirements:** Darktide, Darktide Mod Framework and its working mod-loader setup.

**Install:** extract `Darktide_Greyscale` from the attached ZIP into the game's `mods` folder. Add `Darktide_Greyscale` once to `mods/mod_load_order.txt`, after `dmf`, then enable the effect in Mod Options. Keep folder/entry case unchanged on Linux. Use the attached install ZIP, not GitHub's source archives.

**Update/rollback:** close the game and back up the existing mod folder and load-order file before replacing this mod. Existing saved desaturation values remain unchanged; select 90 manually if needed. To remove it, close the game, remove its load-order line and move the folder out of `mods`.

Validation: Lua syntax checks, 140 mock assertions and install-ZIP content/CRC validation passed. No game assets or third-party mod source are bundled. MIT licensed.
