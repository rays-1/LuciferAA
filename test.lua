-- Service initialization
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local autoSellConfig = {
    Rare = true,
    Epic = false,
    Legendary = false,
    Cooldown = 0.5 -- Seconds between checks
}

-- Track processed units to prevent duplicate actions
local processedUnits = {}
local endpoints = ReplicatedStorage:WaitForChild("endpoints"):WaitForChild("client_to_server")
local sellEndpoint = endpoints:WaitForChild("sell_units")

-- Function to safely sell units
local function processUnit(uniqueId, unitEntry)
    if processedUnits[uniqueId] then return end
    
    local unitId = unitEntry.unit_id
    local unitInfo = UnitData[unitId]
    
    if not unitInfo then
        warn(string.format("Unknown unit ID: %s", unitId))
        return
    end

    local rarity = unitInfo.rarity or "Common"
    
    if autoSellConfig[rarity] then
        local success, result = pcall(function()
            return sellEndpoint:InvokeServer({uniqueId})
        end)
        
        if success then
            print(string.format("Sold %s (Rarity: %s)", unitInfo.name, rarity))
            processedUnits[uniqueId] = true
        else
            warn(string.format("Failed to sell %s: %s", unitInfo.name, result))
        end
    else
        print(string.format("Keeping %s (Rarity: %s)", unitInfo.name, rarity))
        processedUnits[uniqueId] = true
    end
end

-- Continuous monitoring function
local function monitorCollection()
    while task.wait(autoSellConfig.Cooldown) do
        local currentCollection = ItemInventoryService.session.collection.collection_profile_data.owned_units
        
        if not currentCollection then
            warn("Collection data unavailable during monitoring")
            continue
        end

        print("\n=== SCANNING FOR NEW UNITS ===")
        
        -- Check for new or updated entries
        for uniqueId, unitEntry in pairs(currentCollection) do
            if type(unitEntry) == "table" and unitEntry.unit_id then
                if not processedUnits[uniqueId] then
                    processUnit(uniqueId, unitEntry)
                else
                    -- Optional: Add update check here if units can change rarity
                end
            end
        end
        
        print("=== SCAN COMPLETE ===")
    end
end

-- Initial setup
print("\n=== AUTO-SELL SYSTEM INITIALIZED ===")
print(string.format("Monitoring every %d seconds", autoSellConfig.Cooldown))
print("Configuration:", autoSellConfig)

-- Start monitoring
task.spawn(monitorCollection)