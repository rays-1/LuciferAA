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
local UnitData
pcall(function()
    UnitData = require(ReplicatedStorage.src.Data.Units)
end)

if not UnitData then
    error("Failed to load UnitData from ReplicatedStorage")
end

-- Configuration
local autoSellConfig = {
    Rare = true,
    Epic = false,
    Legendary = false,
    Cooldown = .5
}

-- Track processed units
local processedUnits = {}
local endpoints = ReplicatedStorage:WaitForChild("endpoints")
local sellEndpoint = endpoints:WaitForChild("client_to_server"):WaitForChild("sell_units")

-- Function to handle unit processing
local function processUnit(uniqueId, unitEntry)
    if processedUnits[uniqueId] then return end

    local unitId = unitEntry.unit_id
    local unitInfo = UnitData[unitId]
    
    if not unitInfo then
        warn("Unknown unit ID: " .. unitId)
        return
    end

    local rarity = unitInfo.rarity or "Common"
    local args = { { uniqueId } }

    if autoSellConfig[rarity] then
        local success, result = pcall(function()
            sellEndpoint:InvokeServer(unpack(args))
        end)
        
        if success then
            print("Sold " .. unitInfo.name .. " (" .. rarity .. ")")
            processedUnits[uniqueId] = true
        else
            warn("Failed to sell unit: " .. tostring(result))
        end
    else
        print("Keeping " .. unitInfo.name .. " (" .. rarity .. ")")
        processedUnits[uniqueId] = true
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