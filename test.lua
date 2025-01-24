-- SimpleSpy initialization
if not SimpleSpy then
    loadstring(game:HttpGet("https://github.com/exxtremestuffs/SimpleSpySource/raw/master/SimpleSpy.lua"))()
end

-- Service initialization
local Loader = require(game:GetService("ReplicatedStorage").src.Loader)

local success, ItemInventoryService = pcall(function()
    return Loader.load_client_service(script, "ItemInventoryServiceClient")
end)

if not success or not ItemInventoryService then
    error("Failed to load ItemInventoryServiceClient: " .. tostring(ItemInventoryService))
end

-- Load unit data from ReplicatedStorage
local UnitData = require(game:GetService("ReplicatedStorage").src.Data.Units)
local collection = ItemInventoryService.session.collection.collection_profile_data.owned_units

if not collection then
    error("Unit collection not found!")
end

-- Print formatted unit information
print("\n=== UNIT COLLECTION WITH RARITIES ===\n")

for uniqueId, unitEntry in pairs(collection) do
    if unitEntry and unitEntry.unit_id then
        local unitId = unitEntry.unit_id
        local unitInfo = UnitData[unitId]
        
        if unitInfo then
            local displayName = unitInfo.name or "Unknown Unit"
            local rarity = unitInfo.rarity or "Common"
            local shinyStatus = unitEntry["shiny"] and "✨ SHINY" or ""
            
            print(SimpleSpy:ValueToString(unitEntry))
            print(string.format(
                "[%s] %s %s\n- Rarity: %s\n- Base Damage: %s\n- Type: %s\n- Cost: %s\n",
                unitId:upper(),
                displayName,
                shinyStatus,
                rarity:upper(),
                unitInfo.damage or "N/A",
                unitInfo._base_damage_type or "Unknown",
                unitInfo.cost or "Free"
            ))
            
            -- Show upgrade path if available
            if unitInfo.upgrade then
                local maxLevel = #unitInfo.upgrade
                local finalDamage = unitInfo.upgrade[maxLevel].damage
                print(`  Can upgrade to: {finalDamage} damage (Lvl {maxLevel})`)
            end
        else
            warn(string.format("Unknown unit ID: %s", unitId))
        end
    end
end

print("\n=== COLLECTION SUMMARY ===")
print(string.format("Total units owned: %d", table.count(collection)))