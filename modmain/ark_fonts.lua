
local cus_font = {
    'segeoui_alphanum_italic',
}

local prefabs = {}
for _,v in pairs(cus_font) do
    table.insert(prefabs,'font_' .. v)
end

local function ApplyCustomFonts()

    for k,v in pairs(cus_font) do TheSim:UnloadFont(v..'font') end

    TheSim:UnloadPrefabs(prefabs)
    for _,v in pairs(cus_font) do
        local assets = {Asset("FONT",MODROOT.."fonts/"..v..".zip")}
        RegisterSinglePrefab(Prefab('font_'..v, nil, assets))
    end
    TheSim:LoadPrefabs(prefabs)

    for k,v in pairs(cus_font) do
        TheSim:LoadFont(MODROOT.."fonts/"..v..".zip",v..'font')
        TheSim:SetupFontFallbacks(v..'font', DEFAULT_FALLBACK_TABLE)
    end

    for _,v in pairs(cus_font) do 
        rawset(GLOBAL, string.upper(v)..'FONT', v..'font')
    end

end
local OriginUnregisterAllPrefabs = Sim.UnregisterAllPrefabs
Sim.UnregisterAllPrefabs = function(self, ...)
    OriginUnregisterAllPrefabs(self, ...)
    ApplyCustomFonts()
end

local OriginRegisterPrefabs = ModManager.RegisterPrefabs
ModManager.RegisterPrefabs = function(self)
    OriginRegisterPrefabs(self)
    ApplyCustomFonts()
end

local OriginStart = Start
function GLOBAL.Start()
    ApplyCustomFonts()
    OriginStart()
end