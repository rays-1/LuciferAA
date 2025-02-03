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


-- Define the RemoteFunctions
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local spawnUnitRemote = ReplicatedStorage.endpoints.client_to_server.spawn_unit
local upgradeUnitRemote = ReplicatedStorage.endpoints.client_to_server.upgrade_unit_ingame
local sellUnitRemote = ReplicatedStorage.endpoints.client_to_server.sell_unit_ingame

local logArray = {}

local function logArguments(remoteName, ...)
    local args = {...} 
    if remoteName == "upgrade_unit_ingame" or remoteName == "sell_unit_ingame" then
        table.insert(logArray, {
            Remote = remoteName,
            Arguments = args,
            etc = args[1]:GetAttribute("_SPAWN_UNIT_UUID")
        })
    else
        table.insert(logArray, {
            Remote = remoteName,
            Arguments = args
        })
    end
    print("["..remoteName.."] Invoked with arguments:", unpack(args))

end

local mt = getrawmetatable(game)
local oldInvokeServer = mt.__namecall

setreadonly(mt, false) 
mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if method == "InvokeServer" then
        if self == spawnUnitRemote then
            logArguments("spawn_unit", ...)
        elseif self == upgradeUnitRemote then
            logArguments("upgrade_unit_ingame", ...)
        elseif self == sellUnitRemote then
            logArguments("sell_unit_ingame", ...)
        end
    end
    return oldInvokeServer(self, ...)
end)
setreadonly(mt, true) 

while true do
    print("Log Array Contents:")
    for i, entry in ipairs(logArray) do
        print("Entry ["..i.."]: Remote = "..entry.Remote..", Arguments = "..unpack(entry.Arguments).." , etc: "..entry.args)
    end
    task.wait(1)
end