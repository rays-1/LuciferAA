local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Remotes to watch
local spawnUnitRemote = ReplicatedStorage.endpoints.client_to_server.spawn_unit
local upgradeUnitRemote = ReplicatedStorage.endpoints.client_to_server.upgrade_unit_ingame
local sellUnitRemote = ReplicatedStorage.endpoints.client_to_server.sell_unit_ingame



local GameSettingsService = Loader.load_core_service(script, "GameSettingsService")
local difficulty = GameSettingsService:getDifficulty()
print(difficulty)

local UnitsData = require(game:GetService("ReplicatedStorage").src.Data.Units)

local function printTable(tbl, indent)
    indent = indent or ""
    for key, value in pairs(tbl) do
        if type(value) == "table" then
            print(indent .. tostring(key) .. ": {")
            printTable(value, indent .. "  ")
            print(indent .. "}")
        else
            print(indent .. tostring(key) .. ": " .. tostring(value))
        end
    end
end
local Loader = require(game:GetService("ReplicatedStorage").src.Loader)
local ItemInventoryService = Loader.load_client_service(script,"ItemInventoryServiceClient")
local profileData = ItemInventoryService["session"]["collection"]["collection_profile_data"]
local equippedUnits = profileData["equipped_units"]
local storedUnits = {}

for _,UID in pairs(equippedUnits) do
    storedUnits[#storedUnits+1] = profileData["owned_units"][UID]["unit_id"]
end


printTable(equippedUnits)

-- printTable(UnitsData)