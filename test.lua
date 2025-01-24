-- SimpleSpy initialization (use with caution)
if not SimpleSpy then
    local success, err = pcall(function()
        loadstring(game:HttpGet("https://github.com/exxtremestuffs/SimpleSpySource/raw/master/SimpleSpy.lua"))()
    end)
    if not success then
        warn("Failed to load SimpleSpy: " .. tostring(err))
    end
end

-- Service initialization with retries
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Loader
local maxAttempts = 5

for attempt = 1, maxAttempts do
    local success, result = pcall(function()
        Loader = require(ReplicatedStorage.src.Loader)
    end)
    if success then break end
    if attempt == maxAttempts then
        error("Failed to load Loader after " .. maxAttempts .. " attempts: " .. tostring(result))
    end
    task.wait(1)
end

-- Service loading with validation
local ItemInventoryService
local success, err = pcall(function()
    ItemInventoryService = Loader.load_client_service(script, "ItemInventoryServiceClient")
end)

if not success or not ItemInventoryService then
    error("Failed to load ItemInventoryServiceClient: " .. tostring(err))
end

-- Data validation



-- Configuration
local autoSellConfig = {
    Rare = true,
    Epic = false,
    Legendary = false,
    Cooldown = .5
}

-- Track processed units
local UnitData = require(ReplicatedStorage.src.Data.Units)
local processedUnits = {}
local endpoints = ReplicatedStorage:WaitForChild("endpoints")
local sellEndpoint = endpoints:WaitForChild("client_to_server"):WaitForChild("sell_units")

local function processUnit(uniqueId, unitEntry)
    if processedUnits[uniqueId] then return end

    -- Add nil checks for critical components
    if not unitEntry or not unitEntry.unit_id then
        warn("Invalid unit entry for ID: " .. tostring(uniqueId))
        return
    end

    local unitId = unitEntry.unit_id
    local unitInfo = UnitData[unitId]
    
    if not unitInfo then
        warn("Unknown unit ID: " .. tostring(unitId))
        return
    end

    -- Safely handle potentially missing values
    local rarity = unitInfo.rarity or "Common"
    local unitName = unitInfo.name or "Unknown Unit"

    local args = { { tostring(uniqueId) } }  -- Ensure uniqueId is string

    if autoSellConfig[rarity] then
        local success, result = pcall(function()
            sellEndpoint:InvokeServer(unpack(args))
        end)
        
        if success then
            -- Safe string concatenation using format
            print(string.format("Sold %s (Rarity: %s)", unitName, rarity))
            processedUnits[uniqueId] = true
        else
            warn(string.format("Failed to sell %s: %s", unitName, tostring(result)))
        end
    else
        print(string.format("Keeping %s (Rarity: %s)", unitName, rarity))
        processedUnits[uniqueId] = true
    end

    -- Display upgrade info safely
    if unitInfo.upgrade then
        local maxLevel = #unitInfo.upgrade
        local finalDamage = unitInfo.upgrade[maxLevel] and unitInfo.upgrade[maxLevel].damage or "N/A"
        print(string.format("  Can upgrade to: %s damage (Lvl %d)", finalDamage, maxLevel))
    end
end

-- Monitoring system
local function monitorCollection()
    while task.wait(autoSellConfig.Cooldown) do
        local collection = ItemInventoryService.session.collection.collection_profile_data.owned_units
        
        if not collection then
            warn("Collection data not available!")
            continue
        end

        print("\n=== SCANNING COLLECTION ===")
        
        for uniqueId, unitEntry in pairs(collection) do
            if unitEntry and unitEntry.unit_id then
                processUnit(uniqueId, unitEntry)
            end
        end
        
        print("=== SCAN COMPLETE ===\n")
    end
end

-- Initial scan
print("\n=== INITIAL UNIT SCAN ===")
local initialCollection = ItemInventoryService.session.collection.collection_profile_data.owned_units
if initialCollection then
    for uniqueId, unitEntry in pairs(initialCollection) do
        if unitEntry and unitEntry.unit_id then
            processUnit(uniqueId, unitEntry)
        end
    end
end

-- Start continuous monitoring
task.spawn(monitorCollection)
print("\n=== AUTO-SELL SYSTEM ACTIVE ===")