return {
    name = "Darktide Greyscale",
    description = "Experimental gameplay-camera desaturation. Native enemy outlines may also lose colour. Defaults off.",
    is_togglable = true,
    options = {
        widgets = {
            { setting_id = "enabled", type = "checkbox", default_value = false },
            {
                setting_id = "desaturation", type = "numeric", default_value = 90,
                range = {0, 100}, decimals_number = 0, step_size_value = 5,
            },
        },
    },
}
