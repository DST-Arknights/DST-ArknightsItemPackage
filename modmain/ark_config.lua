
-- language
local lang = GetModConfigData('language')
if lang ~= 'auto' then
    TUNING.ARK_CONFIG.language = lang
end

TUNING.ARK_CONFIG.enable_all_materials_drop = GetModConfigData('enable_all_materials_drop')
