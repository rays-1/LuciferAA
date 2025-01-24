-- Service initialization
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Safe service loading with retries
local Loader
local maxAttempts = 5
local attempt = 0

repeat
    attempt += 1
    Loader = require(ReplicatedStorage:WaitForChild("src"):WaitForChild("Loader"))
    task.wait(1)
until Loader or attempt >= maxAttempts

if not Loader then
    error("Failed to load Loader after " .. maxAttempts .. " attempts")
end

-- Service initialization with validation
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
    Legendary = false
}

-- Wait for collection data to be available
local collection
local waitTimeout = 10 -- seconds
local startTime = os.time()

repeat
    if ItemInventoryService.session and
       ItemInventoryService.session.collection and
       ItemInventoryService.session.collection.collection_profile_data then
        collection = ItemInventoryService.session.collection.collection_profile_data.owned_units
    end
    task.wait(1)
until collection or (os.time() - startTime) >= waitTimeout

if not collection then
    error("Unit collection not found after " .. waitTimeout .. " seconds")
end

-- Main processing
print("\n=== UNIT COLLECTION PROCESSING ===")

local endpoints = ReplicatedStorage:WaitForChild("endpoints"):WaitForChild("client_to_server")
local sellEndpoint = endpoints:WaitForChild("sell_units")

for uniqueId, unitEntry in pairs(collection) do
    if type(unitEntry) == "table" and unitEntry.unit_id then
        local unitId = unitEntry.unit_id
        local unitInfo = UnitData[unitId]

        if unitInfo then
            local rarity = unitInfo.rarity or "Common"
            
            if autoSellConfig[rarity] then
                -- Safe sell execution with validation
                pcall(function()
                    sellEndpoint:InvokeServer({uniqueId})
                    print(string.format("Sold %s (Rarity: %s)", unitInfo.name, rarity))
                end)
            else
                print(string.format("Keeping %s (Rarity: %s)", unitInfo.name, rarity))
            end
        else
            warn(string.format("Unknown unit ID: %s", unitId))
        end
    end
end

print("\n=== PROCESSING COMPLETE ===")