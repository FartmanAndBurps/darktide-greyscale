return {
    run = function()
        fassert(rawget(_G, "new_mod"), "Darktide_Greyscale requires Darktide Mod Framework.")
        new_mod("Darktide_Greyscale", {
            mod_script = "Darktide_Greyscale/scripts/mods/Darktide_Greyscale/Darktide_Greyscale",
            mod_data = "Darktide_Greyscale/scripts/mods/Darktide_Greyscale/Darktide_Greyscale_data",
            mod_localization = "Darktide_Greyscale/scripts/mods/Darktide_Greyscale/Darktide_Greyscale_localization",
        })
    end,
    packages = {},
}
