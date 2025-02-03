repeat task.wait() until game:IsLoaded()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local spawnUnitRemote = ReplicatedStorage.endpoints.client_to_server.spawn_unit
local upgradeUnitRemote = ReplicatedStorage.endpoints.client_to_server.upgrade_unit_ingame
local sellUnitRemote = ReplicatedStorage.endpoints.client_to_server.sell_unit_ingame
local Loader = require(game:GetService("ReplicatedStorage").src.Loader)
local ItemInventoryService = Loader.load_client_service(script,"ItemInventoryServiceClient")
local profileData = ItemInventoryService["session"]["collection"]["collection_profile_data"]
local equippedUnits = profileData["equipped_units"]
local UnitsData = require(game:GetService("ReplicatedStorage").src.Data.Units)
local p = workspace._MAP_CONFIG.GetLevelData:InvokeServer()
local logArray = {}
local currUnitNames = {}

local macroConfig = {
    GameMode = p["_gamemode"],
    Name = p["_location_name"]
}

local macroDirectory = "LuciferMacros"

-- Ensure the directory exists
if not isfolder(macroDirectory) then
    makefolder(macroDirectory)
end


local isMacroPlaying = false

function StringToCFrame(String)
    local Split = string.split(String, ",")
    return CFrame.new(Split[1],Split[2],Split[3],Split[4],Split[5],Split[6],Split[7],Split[8],Split[9],Split[10],Split[11],Split[12])
end

local function logArguments(remoteName, ...)
    if isMacroPlaying then
        return
    end

    local args = {...}
    local stepData = {}
    if remoteName == "spawn_unit" then
        local unitName = profileData["owned_units"][args[1]]["unit_id"]
        local cframe = args[2]
        local cost = UnitsData[unitName]["cost"]
        stepData = {
            type = "spawn_unit",
            unit = unitName,
            cframe = tostring(cframe),
            cost = cost
        }
    elseif remoteName == "upgrade_unit_ingame" then
        local unitInstance = args[1]
        local unitUpgNum = args[1]._stats.upgrade.Value+1 or 1
        local unitName = args[1]._stats.id.Value
        local cframe = unitInstance.PrimaryPart and unitInstance._shadow.CFrame or CFrame.new()
        local cost = UnitsData[unitName]["upgrade"][tonumber(unitUpgNum)].cost
        stepData = {
            type = "upgrade_unit_ingame",
            cframe = tostring(cframe),
            cost = cost
        }
    elseif remoteName == "sell_unit_ingame" then
        local unitInstance = args[1]
        local cframe = unitInstance.PrimaryPart and unitInstance._shadow.CFrame or CFrame.new()
        stepData = {
            type = "sell_unit_ingame",
            cframe = tostring(cframe)
        }
    end
    table.insert(logArray, stepData)
    print("["..remoteName.."] Logged step:", stepData)
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

local function saveLogArrayToJson(filePath)
    local HttpService = game:GetService("HttpService")
    local structuredData = {
        MacroConfig = macroConfig,
        Steps = logArray
    }
    local json = HttpService:JSONEncode(structuredData)
    writefile(""..filePath, json)
    print("LogArray saved to JSON file at:", filePath)
end

local function loadLogArrayFromJson(filePath)
    if not isfile(filePath) then
        warn("File does not exist:", filePath)
        return
    end
    local HttpService = game:GetService("HttpService")
    local json = readfile(filePath)
    local loadedData = HttpService:JSONDecode(json)
    macroConfig = loadedData.MacroConfig or {}
    logArray = loadedData.Steps or {}
    print("LogArray loaded from JSON file at:", filePath)
end

local function argumentsToString(stepData)
    local result = {}
    for key, value in pairs(stepData) do
        table.insert(result, key .. ": " .. tostring(value))
    end
    return table.concat(result, ", ")
end

local function findUID(unitName)
    for _, UID in pairs(equippedUnits) do
        if profileData["owned_units"][UID]["unit_id"] == unitName then
            return UID
        end
    end
    return nil
end

local function playMacro()
    isMacroPlaying = true
    for i, stepData in ipairs(logArray) do
        local stepString = argumentsToString(stepData)
        print("Replaying Step ["..i.."]: "..stepString)
        if stepData.type == "spawn_unit" then
            local unitName = findUID(stepData.unit)
            local cframe = StringToCFrame(stepData.cframe)
            local cost = stepData.cost
            repeat task.wait() until game:GetService("Players").LocalPlayer._stats.resource.Value >= cost
            spawnUnitRemote:InvokeServer(unitName, cframe)
        elseif stepData.type == "upgrade_unit_ingame" then
            local cframe = StringToCFrame(stepData.cframe).Position
            local targetUnit = nil
            local cost = stepData.cost
            repeat task.wait() until game:GetService("Players").LocalPlayer._stats.resource.Value >= cost
            for _, unit in ipairs(workspace._UNITS:GetChildren()) do
                local playr = unit:FindFirstChild("_stats"):FindFirstChild("player")
                if playr and tostring(unit._stats.player.Value) == game.Players.LocalPlayer.Name then
                    if unit.PrimaryPart and unit:FindFirstChild("_shadow").CFrame.Position == cframe then
                        targetUnit = unit
                        break
                    end    
                end
            end
            if not targetUnit then
                warn("Failed to find unit with CFrame:", stepData.cframe)
                continue
            end
            upgradeUnitRemote:InvokeServer(targetUnit)
        elseif stepData.type == "sell_unit_ingame" then
            local cframe = StringToCFrame(stepData.cframe).Position
            local targetUnit = nil
            for _, unit in ipairs(workspace._UNITS:GetChildren()) do
                local playr = unit:FindFirstChild("_stats"):FindFirstChild("player")
                if playr and tostring(unit._stats.player.Value) == game.Players.LocalPlayer.Name then
                    if unit.PrimaryPart and unit:FindFirstChild("_shadow").CFrame.Position == cframe then
                        targetUnit = unit
                        break
                    end    
                end
            end
            if not targetUnit then
                warn("Failed to find unit with CFrame:", stepData.cframe)
                continue
            end
            sellUnitRemote:InvokeServer(targetUnit)
        end
        task.wait(1)
    end
    isMacroPlaying = false
    print("Macro playback complete.")
end

task.spawn(function ()
    while true do
        print("Log Array Contents:")
        for i, stepData in ipairs(logArray) do
            local stepString = argumentsToString(stepData)
            print("Step ["..i.."]: "..stepString)
        end
        task.wait(1)
    end
end)

task.wait(60)
saveLogArrayToJson("logArray.json")

task.wait(10)
loadLogArrayFromJson("logArray.json")

playMacro()