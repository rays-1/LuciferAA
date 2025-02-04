-- Constants and Configurations
local macroDirectory = "LuciferMacros"

if not isfolder(macroDirectory) then
    makefolder(macroDirectory)
    print("Created folder:", macroDirectory)
end


local CONSTANTS = {
    MAX_ATTEMPTS = 5,
    TELEPORT_ID =  8304191830,
    TELEPORT_COOLDOWN = 2,
    ALLOWED_DOMAINS = { "github.com", "raw.githubusercontent.com" },
}

local CONFIG = {
    autoSellConfig = {
        Rare = false,
        Epic = false,
        Legendary = false,
        Cooldown = 0.5,
        AutoSellEnabled = false
    },
    friendJoinerConfig = {
        name = "",
    },
    friendWaiterConfig = {
        name = ""
    },
    joinerConfig = {
        waitForFriend = false,
        waitTil = 0,
        enabled = false,
        friendOnly = false,
        lobby = "",
        hardMode = "Normal",
        worldJoinerConfig = {
            World = "Planet Greenie",
            Act = nil -- Will be loaded later
        }
    },
    joinerChallConfig = {
        enabled = false,
        lobby = "",
        selectWorld = {

        },
        selectChall = {
            
        },
        selectRew = {

        }
    },
    joinerLegendConfig = {
        enabled = false,
        lobby = "",
        World = "",
        Act = "",
    },
    joinerRaidConfig = {
        enabled = false,
        lobby = "",
        World = "",
        Act = "",
    },
    MacroConfig = {
        SelectedMacro = "",
        WorldsMacro = {

        }
    },
    DEBUG_MODE = true,
    LuciferVer = "v0.1.0",
    AutoSellCooldown = 0.5,
    LobbyCheckInterval = 5
}
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ws = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local Loader
local src = ReplicatedStorage:WaitForChild("src")
local data = src:WaitForChild("Data")
local UnitData = require(data.Units)
local endpoints = ReplicatedStorage:WaitForChild("endpoints")
local clientToServer = endpoints:WaitForChild("client_to_server")
local sellEndpoint = clientToServer:WaitForChild("sell_units")
local joinRemote = clientToServer:WaitForChild("request_join_lobby")
local leaveRemote = clientToServer:WaitForChild("request_leave_lobby")
local startRemote = clientToServer:WaitForChild("request_start_game")
local lockRemote = clientToServer:WaitForChild("request_lock_level")
local spawnUnitRemote = clientToServer:WaitForChild("spawn_unit")
local upgradeUnitRemote = clientToServer:WaitForChild("upgrade_unit_ingame")
local sellUnitRemote = clientToServer:WaitForChild("sell_unit_ingame")
local UnitsData = require(data.Units)
local WorldsSrc = data:WaitForChild("Worlds")
local originalProperties = {}
local optimized = false
local processedUnits = {}
local lastScan = 0
local ItemInventoryService

-- Helper Functions

-- Error Handling Function
local function handleLoadError(resourceName, attempts, err)
    error(string.format("Failed to load %s after %d attempts: %s", resourceName, attempts, tostring(err)))
end

-- URL Validation Function
local function validateUrl(url)
    for _, domain in ipairs(CONSTANTS.ALLOWED_DOMAINS) do
        if url:find(domain, 1, true) then return true end
    end
    return false
end

-- Safe Load Function
local function attemptLoad(url, attempts)
    if not validateUrl(url) then
        error("Invalid URL: " .. url)
    end
    for attempt = 1, attempts do
        local success, result = pcall(function()
            return loadstring(game:HttpGet(url))()
        end)
        if success then
            return result
        end
        if attempt == attempts then
            handleLoadError("resource at " .. url, attempts, result)
        end
        task.wait(1)
    end
end

-- System Start/Stop Function
local function manageSystem(systemVar, startFunc, stopFunc, systemName)
    if systemVar then
        task.cancel(systemVar)
        systemVar = nil
        stopFunc()
        print(string.format("\n=== %s SYSTEM DEACTIVATED ===", systemName))
    elseif not systemVar then
        systemVar = task.spawn(startFunc)
        print(string.format("\n=== %s SYSTEM ACTIVATED ===", systemName))
    end
    return systemVar
end


local function notify(title, content)
    Fluent:Notify({ Title = title, Content = content, Duration = 5 })
end


-- Load External Libraries
local Fluent = attemptLoad("https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/release.lua", CONSTANTS.MAX_ATTEMPTS)
local SaveManager = attemptLoad("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua", CONSTANTS.MAX_ATTEMPTS)
local InterfaceManager = attemptLoad("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua", CONSTANTS.MAX_ATTEMPTS)
local SimpleSpy = attemptLoad("https://github.com/exxtremestuffs/SimpleSpySource/raw/master/SimpleSpy.lua",CONSTANTS.MAX_ATTEMPTS)
-- Load Loader Module
for attempt = 1, CONSTANTS.MAX_ATTEMPTS do
    local success, result = pcall(function()
        Loader = require(ReplicatedStorage.src.Loader)
    end)
    if success then break end
    if attempt == CONSTANTS.MAX_ATTEMPTS then
        handleLoadError("Loader", CONSTANTS.MAX_ATTEMPTS, result)
    end
    task.wait(1)
end


--  Load ItemInventoryService
local success, err = pcall(function()
    ItemInventoryService = Loader.load_client_service(script, "ItemInventoryServiceClient")
end)
if not success or not ItemInventoryService then
    error("Failed to load ItemInventoryServiceClient: " .. tostring(err))
end
local profileData = ItemInventoryService.session.collection.collection_profile_data
local equippedUnits = profileData.equipped_units

-- Get World Data
local Worlds = {}
local WorldsLegend = {}
local WorldsRaid = {}
for _, moduleScript in ipairs(WorldsSrc:GetChildren()) do
    if moduleScript:IsA("ModuleScript") and moduleScript.Name ~= "UnitPresets" then
        local worldData = require(moduleScript)

        for _, worldEntry in pairs(worldData) do
            if worldEntry["legend_stage"] == true then
                local formatted = {
                }
    
                -- Parse levels
                for i = 1, 6 do
                    local levelKey = tostring(i)
                    if worldEntry.levels[levelKey] then
                        formatted["Act "..i] = worldEntry.levels[levelKey].id
                    end
                end
    
                -- Use display name as key
                WorldsLegend[worldEntry.name] = formatted
            elseif worldEntry["raid_world"] == true then
                local formatted = {
                }
                -- Parse levels
                for i = 1, 6 do
                    local levelKey = tostring(i)
                    if worldEntry.levels[levelKey] then
                        formatted["Act "..i] = worldEntry.levels[levelKey].id
                    end
                end
    
                -- Use display name as key
                WorldsRaid[worldEntry.name] = formatted
            else
                local formatted = {
                }
    
                if worldEntry.infinite then
                    formatted["Infinite"] = worldEntry.infinite.id or nil
                end
                -- Parse levels
                for i = 1, 6 do
                    local levelKey = tostring(i)
                    if worldEntry.levels[levelKey] then
                        formatted["Act "..i] = worldEntry.levels[levelKey].id
                    end
                end
    
                -- Use display name as key
                Worlds[worldEntry.name] = formatted
            end
        end
    end
end

CONFIG.joinerConfig.worldJoinerConfig.Act = Worlds[CONFIG.joinerConfig.worldJoinerConfig.World]["Act 1"]

local worldNames = {}
local worldNamesLegend = {}
local worldNamesRaid = {}
for name in pairs(Worlds) do
    table.insert(worldNames, name)
end
for name in pairs(WorldsLegend) do
    table.insert(worldNamesLegend, name)
end
for name in pairs(WorldsRaid) do
    table.insert(worldNamesRaid, name)
end

-- UI Setup
local Window = Fluent:CreateWindow({
    Title = "Lucifer " .. CONFIG.LuciferVer,
    SubTitle = "Made by Haro",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "home" }),
    Farm = Window:AddTab({ Title = "Farm", Icon = "activity" }),
    Joiner = Window:AddTab({ Title = "Joiner", Icon = "wifi" }),
    Macro = Window:AddTab({Title = "Macro", Icon = "pencil"}),
    ["Farm Config"] = Window:AddTab({ Title = "Farm Config", Icon = "settings" }),
    Shop = Window:AddTab({ Title = "Shop", Icon = "shopping-cart" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "box" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local MainWelcome = Tabs.Main:AddSection("Welcome to Lucifer", 1)
local MainActions = Tabs.Main:AddSection("Quick Actions", 2)

local joinerSets = Tabs.Joiner:AddSection("Joiner Settings",1)
local friendSection = Tabs.Joiner:AddSection("Join Friend", 2)
local autoJoinWorldSection = Tabs.Joiner:AddSection("Auto Join World", 3)
local autoJoinChallSection = Tabs.Joiner:AddSection("Auto Join Challenge",4)
local autoJoinLegenSection = Tabs.Joiner:AddSection("Auto Join Legend",5)
local autoJoinRaidSection = Tabs.Joiner:AddSection("Auto Join Raid",5)

local shopMainSection = Tabs.Shop:AddSection("Auto Sell Configuration", 1)

local miscMainSection = Tabs.Misc:AddSection("Optimization Settings", 1)
local miscExtraSection = Tabs.Misc:AddSection("Other Utilities", 2)
local diagnosticsSection = Tabs.Misc:AddSection("Diagnostics", 3)

local macroRecorder = Tabs.Macro:AddSection("Macro Recorder",1)

Tabs["Farm Config"]:AddSection("Combat Settings", 1)
Tabs["Farm Config"]:AddSection("Target Filters", 2)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
Window:SelectTab(1)

-- Thread Variables
local autoJoining
local autoJoiningLegend
local autoJoiningRaid
local followingPLayer
local waitingPlayer
local autoChallenge
local macroPlaying

-- Macro Variables
local isRecording = false
local isPlaying = false
local recordedActions = {}
local macroStartTime = 0
local logArray = {}
local currUnitNames = {}
local isMacroPlaying = false


-- UI Variables
local teleportClickCount = 0
local isTeleporting = false
local friendIsIn = false

if game.PlaceId ~= CONSTANTS.TELEPORT_ID then
    local p = workspace._MAP_CONFIG.GetLevelData:InvokeServer()
    local macroConfig = {
        GameMode = p["_gamemode"],
        Name = p["_location_name"]
    } 
    
end

-- Macro Functions
-- Macro Functions
local function StringToCFrame(String)
    local Split = string.split(String, ",")
    return CFrame.new(Split[1],Split[2],Split[3],Split[4],Split[5],Split[6],Split[7],Split[8],Split[9],Split[10],Split[11],Split[12])
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

local function logArguments(remoteName, ...)
    if isMacroPlaying or not isRecording then return end

    local args = {...}
    local stepData = {}
    local timestamp = os.clock() - macroStartTime
    
    if remoteName == "spawn_unit" then
        local unitName = profileData["owned_units"][args[1]]["unit_id"]
        local cframe = args[2]
        local cost = UnitsData[unitName]["cost"]
        stepData = {
            type = "spawn_unit",
            unit = unitName,
            cframe = tostring(cframe),
            cost = cost,
            time = timestamp
        }
    elseif remoteName == "upgrade_unit_ingame" then
        local unitInstance = args[1]
        local unitUpgNum = unitInstance._stats.upgrade.Value+1 or 1
        local unitName = unitInstance._stats.id.Value
        local cframe = unitInstance.PrimaryPart and unitInstance._shadow.CFrame or CFrame.new()
        local cost = UnitsData[unitName]["upgrade"][tonumber(unitUpgNum)].cost
        stepData = {
            type = "upgrade_unit_ingame",
            cframe = tostring(cframe),
            cost = cost,
            time = timestamp
        }
    elseif remoteName == "sell_unit_ingame" then
        local unitInstance = args[1]
        local cframe = unitInstance.PrimaryPart and unitInstance._shadow.CFrame or CFrame.new()
        stepData = {
            type = "sell_unit_ingame",
            cframe = tostring(cframe),
            time = timestamp
        }
    end
    
    table.insert(logArray, stepData)
end

-- local function saveMacro(macroName)
--     local filePath = macroDirectory .. "/" .. macroName .. ".json"
--     local HttpService = game:GetService("HttpService")
--     local structuredData = {
--         MacroConfig = macroConfig,
--         Steps = logArray
--     }
--     local json = HttpService:JSONEncode(structuredData)
--     writefile(filePath, json)
--     print("Macro saved to:", filePath)
-- end

local function printTable(tbl, indent)
    -- Default indentation level
    indent = indent or 0

    -- Iterate through the table
    for key, value in pairs(tbl) do
        -- Create indentation string
        local indentation = string.rep("  ", indent)

        -- Handle different types of values
        if type(value) == "table" then
            -- If the value is a table, print the key and recurse
            print(indentation .. tostring(key) .. ": {")
            printTable(value, indent + 1)
            print(indentation .. "}")
        else
            -- Print the key-value pair
            print(indentation .. tostring(key) .. ": " .. tostring(value))
        end
    end
end

local function loadMacro(macroName)
    local filePath = macroDirectory .. "/" .. macroName .. ".json"
    if not isfile(filePath) then
        warn("File does not exist:", filePath)
        return false
    end

    local HttpService = game:GetService("HttpService")
    local success, json = pcall(readfile, filePath)
    if not success then
        warn("Failed to read file:", filePath)
        return false
    end

    local success, loadedData = pcall(HttpService.JSONDecode, HttpService, json)
    if not success then
        warn("Failed to decode JSON:", filePath)
        return false
    end

    macroConfig = loadedData.MacroConfig or {}
    logArray = loadedData.Steps or {}
    printTable(loadedData)
    task.wait(1)
    return true
end



local function playMacro()
    if macroPlaying ~= nil then 
        task.cancel(macroPlaying)    
        macroPlaying = nil
    end
    macroPlaying = task.spawn(function ()
        print("You're here..")
        isMacroPlaying = true
        print("You're here..")
        for i, stepData in ipairs(logArray) do
            if isMacroPlaying == false then break end
            printTable(stepData)
            print("You're here..")
            local stepString = argumentsToString(stepData)
            notify("Step ["..i.."]: "..stepString)
            print("Replaying Step ["..i.."]: "..stepString)
            if stepData.type == "spawn_unit" then
                local unitName = findUID(stepData.unit)
                local cframe = StringToCFrame(stepData.cframe)
                local cost = stepData.cost
                repeat task.wait() until game:GetService("Players").LocalPlayer._stats.resource.Value >= cost
                if isMacroPlaying == false then break end
                spawnUnitRemote:InvokeServer(unitName, cframe)
            elseif stepData.type == "upgrade_unit_ingame" then
                local cframe = StringToCFrame(stepData.cframe).Position
                local targetUnit = nil
                local cost = stepData.cost
                repeat task.wait() until game:GetService("Players").LocalPlayer._stats.resource.Value >= cost
                if isMacroPlaying == false then break end
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
        print("Macro playback complete.")
        isMacroPlaying = false
        macroPlaying = nil
    end)
end


-- Unit Processing Logic
local function printUnitInfo(unitName, rarity, uniqueId, upgrade)
    local output = string.format("Processed %s (Rarity: %s, UniqueID: %s)", unitName, rarity, uniqueId)
    if upgrade then
         local maxLevel = #upgrade
        local finalDamage = upgrade[maxLevel] and upgrade[maxLevel].damage or "N/A"
        output = output .. string.format("\n  Can upgrade to: %s damage (Lvl %d)", finalDamage, maxLevel)
    end
    print(output)
end


local function processUnit(uniqueId, unitEntry)
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

    local rarity = unitInfo.rarity or "Common"
    local unitName = unitInfo.name or "Unknown Unit"

    local args = { tostring(uniqueId) }

    if CONFIG.autoSellConfig[rarity] and CONFIG.autoSellConfig.AutoSellEnabled then
        if processedUnits[uniqueId] then return end
           sellEndpoint:InvokeServer(args)
            processedUnits[uniqueId] = true
          printUnitInfo(unitName, rarity, uniqueId, unitInfo.upgrade)
            print(string.format("Sold %s (Rarity: %s)", unitName, rarity))

    else
        printUnitInfo(unitName, rarity, uniqueId, unitInfo.upgrade)
        print(string.format("Keeping %s (Rarity: %s)", unitName, rarity))
    end
    processedUnits[uniqueId] = true
end

-- Auto-Sell System
local monitoringTask
local function monitorCollection()
     processedUnits = {}
    lastScan = os.time()
    while task.wait(CONFIG.autoSellConfig.Cooldown) and CONFIG.autoSellConfig.AutoSellEnabled do
        local collection = ItemInventoryService.session.collection.collection_profile_data.owned_units

        if not collection then
            warn("Collection data not available!")
        end

        print("\n=== SCANNING COLLECTION ===")

        for uniqueId, unitEntry in pairs(collection) do
             if unitEntry and unitEntry.unit_id then
                processUnit(uniqueId, unitEntry)
            end
        end

        print("=== SCAN COMPLETE ===\n")
         if not CONFIG.autoSellConfig.AutoSellEnabled then break end
          diagnosticsSection:Clear()
        diagnosticsSection:AddLabel("Processed Units: " .. table.size(processedUnits))
    end
end
local function startMonitoring()
    if monitoringTask then
        task.cancel(monitoringTask)
        monitoringTask = nil
    end
    monitoringTask = task.spawn(monitorCollection)
    print("\n=== AUTO-SELL SYSTEM ACTIVE ===")
end
local function stopMonitoring()
    if monitoringTask then
        task.cancel(monitoringTask)
        monitoringTask = nil
    end
    print("\n=== AUTO-SELL SYSTEM DEACTIVATED ===")
end

-- Teleport Logic
local function attemptTeleport()
    if isTeleporting then return end
    isTeleporting = true
    notify("Attempt Teleport", "Attempting to Teleport")
   local success, err = pcall(function()
        TeleportService:Teleport(CONSTANTS.TELEPORT_ID, game.Players.LocalPlayer)
    end)
    if not success then
        notify("Teleport Failed", "Error: " .. tostring(err))
    end
    isTeleporting = false
end
--Teleport Button
local teleportButton = MainActions:AddButton({
    Title = "Teleport to Lobby",
    Description = "Double-click to confirm",
    Callback = function()
        teleportClickCount = teleportClickCount + 1
        if teleportClickCount == 1 then
           task.delay(CONSTANTS.TELEPORT_COOLDOWN, function()
              if teleportClickCount == 1 then
                 teleportClickCount = 0
              end
           end)
        elseif teleportClickCount >= 2 then
             attemptTeleport()
            teleportClickCount = 0
        end
    end
})

-- Lobby Finding Logic
local function getLobbies()
    local lobbies = {}
    for _, instance in ipairs(workspace:GetDescendants()) do
        if instance:IsA("Model") and instance.Name:match("^_lobbytemplate") then
            local playersFolder = instance:FindFirstChild("Players")
            local timerValue = instance:FindFirstChild("Timer")
            if playersFolder and playersFolder:IsA("Folder") and timerValue and timerValue:IsA("IntValue") then
                table.insert(lobbies, instance)
            end
        end
    end
    return lobbies
end
local function findPlayerInLobbies(targetName)
    local allLobbies = getLobbies()
    for _, lobby in ipairs(allLobbies) do
         local lobbyFullName = lobby:GetFullName()
        local lobbyName = lobby.Name
        if lobbyFullName then
            local playersFolder = lobby:FindFirstChild("Players")
            if playersFolder then
                for _, objValue in ipairs(playersFolder:GetChildren()) do
                    if tostring(objValue.Value) == targetName then
                         return lobbyName
                    end
                end
            end
        end
    end
    return nil
end

local function findPlayerInRaids(targetName)
    local allLobbies = getLobbies()
    for _, lobby in ipairs(allLobbies) do
        local lobbyFullName = lobby:GetFullName()
        local lobbyName = lobby.Name
        if lobbyFullName then
            if lobby.Parent.Name == "Raid" then
                local playersFolder = lobby:FindFirstChild("Players")
                if playersFolder then
                    for _, objValue in ipairs(playersFolder:GetChildren()) do
                        if tostring(objValue.Value) == targetName then
                             return lobbyName
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- Lobby Joining Logic
local function safeJoinLobby(lobbyName)

    print("Joining lobby: "..lobbyName)
    local args = {
        [1] = tostring(lobbyName)
    }

    joinRemote:InvokeServer(unpack(args))
end
local function joinRandomLobby()
    local freeLobby
    for i = 1, 9 do
        local lobbyName = "_lobbytemplategreen" .. i
        local lobby = workspace._LOBBIES.Story:FindFirstChild(lobbyName)
        if lobby and lobby:FindFirstChild("Active").Value == false then
            local playersFolder = lobby:FindFirstChild("Players")
            if playersFolder then
                if #playersFolder:GetChildren() == 0 then
                    freeLobby = lobbyName
                    
                end
            end
        end
    end
    CONFIG.joinerConfig.lobby = freeLobby
    if freeLobby then
        safeJoinLobby(freeLobby)
    end
    task.wait()
end

local function joinRandomLegend()
    local freeLobby
    for i = 1, 9 do
        local lobbyName = "_lobbytemplategreen" .. i
        local lobby = workspace._LOBBIES.Story:FindFirstChild(lobbyName)
        if lobby and lobby:FindFirstChild("Active").Value == false then
            local playersFolder = lobby:FindFirstChild("Players")
            if playersFolder then
                if #playersFolder:GetChildren() == 0 then
                    freeLobby = lobbyName
                    
                end
            end
        end
    end
    CONFIG.joinerLegendConfig.lobby = freeLobby
    if freeLobby then
        safeJoinLobby(freeLobby)
    end
    task.wait()
end

local function joinRandomRaid()
    local freeLobby
    for i = 1, 5 do
        local lobbyName = "_lobbytemplate21" .. i
        local lobby = workspace._RAID.Raid:FindFirstChild(lobbyName)
        if lobby and lobby:FindFirstChild("Active").Value == false then
            local playersFolder = lobby:FindFirstChild("Players")
            if playersFolder then
                if #playersFolder:GetChildren() == 0 then
                    freeLobby = lobbyName
                    
                end
            end
        end
    end
    CONFIG.joinerRaidConfig.lobby = freeLobby
    if freeLobby then
        safeJoinLobby(freeLobby)
    end
    task.wait()
end


local function joinRandomLobbyChallenge()
    local freeLobby
    for i = 6, 9 do
        local lobbyName = "_lobbytemplate31" .. i
        local lobby = workspace._CHALLENGES.Challenges:FindFirstChild(lobbyName)
        if lobby and lobby:FindFirstChild("Active").Value == false then
            local playersFolder = lobby:FindFirstChild("Players")
            if playersFolder then
                if #playersFolder:GetChildren() == 0 then
                    freeLobby = lobbyName
                end
            end
        end
    end
    CONFIG.joinerChallConfig.lobby = freeLobby
    print("Joining lobby"..tostring(freeLobby))
    if freeLobby then
        safeJoinLobby(freeLobby)
    end
    task.wait()
end
-- Game Optimization
local function optimizeGame()
    if optimized then return end
    optimized = true
    local camera = ws:WaitForChild("Camera")
    print("Optimization started...")

    for _, descendant in ipairs(game:GetDescendants()) do
        if descendant and not descendant:IsDescendantOf(camera) then
            originalProperties[descendant] = originalProperties[descendant] or {}

            if descendant:IsA("BasePart") then
                originalProperties[descendant].Material = descendant.Material
                originalProperties[descendant].CastShadow = descendant.CastShadow
                descendant.Material = Enum.Material.Plastic
                descendant.CastShadow = false
                print(string.format("Optimized BasePart: %s", descendant:GetFullName()))
            end

            if descendant:IsA("Beam") or descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") then
                originalProperties[descendant].Enabled = descendant.Enabled
                descendant.Enabled = false
                 print(string.format("Optimized Visual Effect: %s", descendant:GetFullName()))
            end

            if descendant:IsA("MeshPart") or descendant:IsA("SpecialMesh") then
                 if pcall(function() return descendant.MeshId end) then
                    originalProperties[descendant].MeshId = descendant.MeshId
                     descendant.MeshId = ""
                 end
                  if pcall(function() return descendant.TextureId end) then
                     originalProperties[descendant].TextureId = descendant.TextureId
                     descendant.TextureId = ""
                 end
                print(string.format("Optimized Mesh: %s", descendant:GetFullName()))
            end
            if descendant:IsA("Texture") then
                originalProperties[descendant].Texture = descendant.Texture
                descendant.Texture = ""
                print(string.format("Optimized Texture: %s", descendant:GetFullName()))
            end
        end
           task.wait()
    end
end

local function restoreGame()
    if not optimized then return end
    print("Restoring original state...")

    for descendant, props in pairs(originalProperties) do
        if descendant and descendant.Parent then
            if descendant:IsA("BasePart") then
                if props.Material then
                    descendant.Material = props.Material
                end
                if props.CastShadow ~= nil then
                    descendant.CastShadow = props.CastShadow
                end
                 print(string.format("Restored BasePart: %s", descendant:GetFullName()))
            end

            if descendant:IsA("Beam") or descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") then
                if props.Enabled ~= nil then
                    descendant.Enabled = props.Enabled
                end
                print(string.format("Restored Visual Effect: %s", descendant:GetFullName()))
            end

            if descendant:IsA("MeshPart") or descendant:IsA("SpecialMesh") then
                 if props.MeshId and pcall(function() descendant.MeshId = props.MeshId end) then
                     descendant.MeshId = props.MeshId
                end
                if props.TextureId and pcall(function() descendant.TextureId = props.TextureId end) then
                    descendant.TextureId = props.TextureId
                end
                  print(string.format("Restored Mesh: %s", descendant:GetFullName()))
            end

            if descendant:IsA("Texture") then
               if props.Texture and pcall(function() descendant.Texture = props.Texture end) then
                    descendant.Texture = props.Texture
               end
               print(string.format("Restored Texture: %s", descendant:GetFullName()))
            end
        end
    end
    optimized = false
    table.clear(originalProperties)
end



local function saveMacro(macroName, macroData)
    if macroName then
        local filePath = "LuciferMacros" .. "/" .. macroName .. ".json"
        local HttpService = game:GetService("HttpService")
        local json = HttpService:JSONEncode(macroData)
        writefile(filePath, json)
        print("Macro saved to:", filePath) 
    end
end

local function tableContains(tbl, value)
    for x, v in pairs(tbl) do
        -- If the current element is a table, recurse into it
        if type(x) == "table" then
            if tableContains(x, value) then
                return true
            end
        else
            -- If the current element matches the value, return true
            if x == value then
                return true
            end
        end
    end
    return false
end



local function findWorldByActID(act_id)
    -- Iterate through each world in the Worlds table
    for world_name, acts in pairs(Worlds) do
        -- Check each act in the current world
        for act_name, id in pairs(acts) do
            if id == act_id then
                -- Return the world name if the act_id matches
                return world_name
            end
        end
    end
    -- If no match is found, return nil
    return nil
end
--  Auto Join Systems Logic
local function followPlayer()
    while true do
        task.wait(CONFIG.LobbyCheckInterval)
        local targetLobby = findPlayerInLobbies(CONFIG.friendJoinerConfig.name)
        if targetLobby then
            if currentLobby == targetLobby then
                if CONFIG.DEBUG_MODE then
                    print("Already in correct lobby:", targetLobby)
                end
            else
                if currentLobby then
                    if CONFIG.DEBUG_MODE then
                        print("Leaving current lobby:", currentLobby)
                    end
                     local args = {
                        [1] = currentLobby
                    }
                     leaveRemote:InvokeServer(unpack(args))
                end
                if CONFIG.DEBUG_MODE then
                    print("Attempting to join:", targetLobby)
                end
                 local args = {
                        [1] = targetLobby
                    }
                 joinRemote:InvokeServer(unpack(args))
                currentLobby = targetLobby
                lastValidLobby = targetLobby
            end
        else
            if CONFIG.DEBUG_MODE then
                print("Target player not found in any lobby")
            end
        end
    end
end
local function lockInLevel()
    local args = {
        [1] = CONFIG.joinerConfig.lobby,
        [2] = CONFIG.joinerConfig.worldJoinerConfig.Act,
        [3] = CONFIG.joinerConfig.friendOnly,
        [4] = CONFIG.joinerConfig.hardMode
    }
    if CONFIG.joinerConfig.worldJoinerConfig.Act == "Infinite" then
        args[4] = "Hard"
    end
    lockRemote:InvokeServer(unpack(args))
end
local function lockInLegend()
    local args = {
        [1] = CONFIG.joinerLegendConfig.lobby,
        [2] = CONFIG.joinerLegendConfig.Act,
        [3] = CONFIG.joinerConfig.friendOnly,
        [4] = "Hard"
    }

    lockRemote:InvokeServer(unpack(args))
end

local function lockInRaid()
    local args = {
        [1] = CONFIG.joinerRaidConfig.lobby,
        [2] = CONFIG.joinerRaidConfig.Act,
        [3] = CONFIG.joinerConfig.friendOnly,
        [4] = "Hard"
    }

    lockRemote:InvokeServer(unpack(args))
end

local function waitPlayer()
    while true do
        task.wait(3)
        local currentLobby = findPlayerInLobbies(game.Players.LocalPlayer.Name)
        if currentLobby then
            local lobby = workspace._LOBBIES.Story:FindFirstChild(currentLobby)
            local Timer = lobby:FindFirstChild("Timer")
            local playersFolder = lobby:FindFirstChild("Players")
            if #playersFolder:GetChildren() ~= 0 then
                for _, objValue in ipairs(playersFolder:GetChildren()) do
                    if tostring(objValue.Value) == CONFIG.friendWaiterConfig.name then
                        friendIsIn = true
                        print(CONFIG.friendWaiterConfig.name .. " is in room!")
                         -- START CONFIG HERE
                    end
                end
                if Timer.Value <= 20 and Timer.Value ~= -1 then
                     local args = {
                        [1] = currentLobby
                    }
                    CONFIG.joinerConfig.lobby = currentLobby
                    leaveRemote:InvokeServer(unpack(args))
                    task.wait(3)
                end
            end
        end
    end
end

local function reqStartGame()
    local currlob = findPlayerInLobbies(game.Players.LocalPlayer.Name)
    if currlob then
        local args = {
            [1] = currlob
        }
        startRemote:InvokeServer(unpack(args))
    end
end

local function autoJoinWorld()
    while true do
        local currlob = findPlayerInLobbies(game.Players.LocalPlayer.Name)
        if currlob then
            lockInLevel()
            task.wait(CONFIG.joinerConfig.waitTil)
            reqStartGame()
        else
            print("Player Not In Lobby")
            joinRandomLobby()
        end
        task.wait(CONFIG.LobbyCheckInterval)
    end
end
local function startJoin()
   autoJoining = manageSystem(autoJoining, autoJoinWorld, stopJoin, "AUTO-JOIN")
end

local function stopJoin()
    if autoJoining then
        task.cancel(autoJoining)
        autoJoining = nil
    end
    print("\n=== AUTO-JOIN SYSTEM DEACTIVATED ===")
end

local function autoJoinLegend()
    while true do
        local currlob = findPlayerInLobbies(game.Players.LocalPlayer.Name)
        if currlob then
            lockInLegend()
            task.wait(CONFIG.joinerConfig.waitTil)
            reqStartGame()
        else
            print("Player Not In Lobby")
            joinRandomLegend()
        end
        task.wait(CONFIG.LobbyCheckInterval)
    end
end

local function startJoinLegend()
    autoJoiningLegend = manageSystem(autoJoiningLegend, autoJoinLegend, stopJoinLegen, "AUTO-JOIN LEGEND")
 end
 
 local function stopJoinLegend()
     if autoJoiningLegend then
         task.cancel(autoJoiningLegend)
         autoJoiningLegend = nil
     end
     print("\n=== AUTO-JOIN LEGEND SYSTEM DEACTIVATED ===")
 end

 local function autoJoinRaid()
    while true do
        local currlob = findPlayerInRaids(game.Players.LocalPlayer.Name)
        if currlob then
            lockInRaid()
            task.wait(CONFIG.joinerConfig.waitTil)
            reqStartGame()
        else
            print("Player Not In Lobby")
            joinRandomRaid()
        end
        task.wait(CONFIG.LobbyCheckInterval)
    end
end

local function startJoinRaid()
    autoJoiningRaid = manageSystem(autoJoiningRaid, autoJoinRaid, stopJoinRaid, "AUTO-JOIN RAID")
 end
 
 local function stopJoinRaid()
     if autoJoiningRaid then
         task.cancel(autoJoiningRaid)
         autoJoiningRaid = nil
     end
     print("\n=== AUTO-JOIN RAID SYSTEM DEACTIVATED ===")
 end


local function startFollow()
    followingPLayer = manageSystem(followingPLayer,followPlayer, stopFollow, "AUTO-FOLLOW")
end

local function stopFollow()
    if followingPLayer then
        task.cancel(followingPLayer)
        followingPLayer = nil
    end
    print("\n=== AUTO-FOLLOW SYSTEM DEACTIVATED ===")
end

local function startWait()
    waitingPlayer = manageSystem(waitingPlayer, waitPlayer, stopWait, "AUTO-WAIT")
end

local function stopWait()
    if waitingPlayer then
        task.cancel(waitingPlayer)
        waitingPlayer = nil
    end
    print("\n=== AUTO-WAIT SYSTEM DEACTIVATED ===")
end

local function leaveLobbyy()
    local currlob = findPlayerInLobbies(game.Players.LocalPlayer.Name)
    if currlob then
        leaveRemote:InvokeServer(unpack({[1] = currlob}))
    end
end

-- World and Act Dropdown Logic
local function getActsForWorld(worldName)
    local worldData = Worlds[worldName]
    local acts = {}
    for key in pairs(worldData) do
        if key:match("Act %d") then
            table.insert(acts, key)
        end
    end
    acts["Infinite"] = worldData.Infinite
    table.sort(acts)
    return acts
end

local function getLegends(worldName)
    local worldData = WorldsLegend[worldName]
    local acts = {}
    for key in pairs(worldData) do
        print("Key: "..tostring(key))
        if key:match("Act %d") then
            table.insert(acts, key)
        end
    end
    table.sort(acts)
    return acts
end

local function getRaids(worldName)
    local worldData = WorldsRaid[worldName]
    local acts = {}
    for key in pairs(worldData) do
        if key:match("Act %d") then
            table.insert(acts, key)
        end
    end
    table.sort(acts)
    return acts
end


local function getRewards()
    return {"StarFruit","StarFruitGreen","StarFruitRed","StarFruitPink","StarFruitBlue","StarFruitEpic"}
end

local function getChallenges()
    return {"double_cost","short_range","fast_enemies","regen_enemies","tank_enemies","shield_enemies"}
end

local function getCurrentChallenge()
    local currChal
    local currRew = {}
    local currWorld
    local deets = clientToServer:WaitForChild("get_normal_challenge"):InvokeServer()

    for key, val in pairs(deets) do
        if key:match("current_reward") then
            for i,v in ipairs(deets[key]["_rewards"][1]["item"]) do
                currRew[i] = tostring(v["item_id"])
            end
        elseif key:match("current_level_id") then
            currWorld = tostring(findWorldByActID(val))
        elseif key:match("current_challenge") then
            currChal = tostring(val)
        end
    end

    print(currChal)
    print(currRew)
    print(currWorld)
    return {currChal, currRew, currWorld}
end

local function checkChallengeCompletion()
    local p = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    local cleared = false
    for i,v in pairs(p:GetChildren()) do
        if v.Name == "SurfaceGui" then
            local sfg = v:FindFirstChild("ChallengeCleared")
            if sfg and sfg:IsA("Frame") then
                if sfg.Visible then
                    cleared = true
                end
            end
        end
    end

    return cleared
end

local function autoChall()
    while true do
        if checkChallengeCompletion() == false then
            if findPlayerInLobbies(game.Players.LocalPlayer.Name) == nil then
                local info = getCurrentChallenge()
                local info2 = CONFIG.joinerChallConfig
                
                -- Check if ANY reward matches config
                local rewardCheck = false
                for _, rewardId in ipairs(info[2]) do
                    if tableContains(info2.selectRew[1], rewardId) then
                        rewardCheck = true
                    end
                end
        
                local chalCheck = tableContains(info2.selectChall[1], info[1])
                local worlCheck = tableContains(info2.selectWorld[1], info[3])
        
        
                local startJoin = (chalCheck and rewardCheck and worlCheck)
        
        
                print("CAN YOU START THE CHALLENGE?? :".. tostring(startJoin))
                if startJoin then
                    joinRandomLobbyChallenge()
                end 
            end
        end
        task.wait(5)
    end
end

local function stopAutoChallenge()
    if autoChallenge then
        task.cancel(autoChallenge)
        autoChallenge = nil
    end
    print("\n=== AUTO-CHALLENGE SYSTEM DEACTIVATED ===")
end

local function startAutoChallenge()
    autoChallenge = manageSystem(autoChallenge, autoChall, stopAutoChallenge, "AUTO-CHALLENGE")
end

local Options = Fluent.Options

-- UI Elements
local leaveLobbyButton = joinerSets:AddButton({
    Title = "Leave Current Lobby",
    Description = "Leave lobby",
    Callback = function()
        leaveLobbyy()
    end
})
local friendOnly = joinerSets:AddToggle("FriendsOnlyEnabled", {Title = "Friends Only?",Default = CONFIG.joinerConfig.friendOnly})

friendOnly:OnChanged(function(Value)
    CONFIG.joinerConfig.friendOnly = Value
end)

local autoJoinEnable = autoJoinWorldSection:AddToggle("autoJoinEnable", {
    Title = "Enable Auto Join",
    Default = CONFIG.joinerConfig.enabled,
    Callback = function(Value)
        CONFIG.joinerConfig.enabled = Value
        if CONFIG.joinerConfig.enabled then
            startJoin()
        else
            stopJoin()
        end
    end
})
local HardMode = joinerSets:AddToggle("hardModeToggle", {
    Title = "Enable Hard Mode",
    Default = false,
    Callback = function(Value)
        if Value then
           CONFIG.joinerConfig.hardMode = "Hard"
        else
            CONFIG.joinerConfig.hardMode = "Normal"
        end
    end
})
local TimetoLock = joinerSets:AddSlider("TimeToLock",{
    Title = "Wait Seconds To Start",
    Default = 0,
    Min = 0,
    Max = 20,
    Rounding = 1,
    Callback = function(Value)
        CONFIG.joinerConfig.waitTil = Value
    end
})

local actSection = autoJoinWorldSection:AddDropdown("actPicker", {
    Title = "Select Act",
    Description = "Pick an act to join",
    Values = getActsForWorld(CONFIG.joinerConfig.worldJoinerConfig.World),
    Default = "Act 1",
    Multi = false,
    Callback = function(Value)
        CONFIG.joinerConfig.worldJoinerConfig.Act = Worlds[CONFIG.joinerConfig.worldJoinerConfig.World][Value]
    end
})

local worldSection = autoJoinWorldSection:AddDropdown("worldPicker", {
    Title = "Auto Join World",
    Description = "Pick a world to join",
    Values = worldNames,
    Default = CONFIG.joinerConfig.worldJoinerConfig.World,
    Multi = false,
    Callback = function(Value)
        CONFIG.joinerConfig.worldJoinerConfig.World = Value
        actSection:SetValues(getActsForWorld(CONFIG.joinerConfig.worldJoinerConfig.World))
        CONFIG.joinerConfig.worldJoinerConfig.Act = Worlds[CONFIG.joinerConfig.worldJoinerConfig.World]["Act 1"]
        actSection:SetValue("Act 1")
    end
})

local AutoSellEnabledToggle = shopMainSection:AddToggle("AutoSellEnabled", {
    Title = "Enable Auto Sell",
    Default = CONFIG.autoSellConfig.AutoSellEnabled
})

AutoSellEnabledToggle:OnChanged(function()
    CONFIG.autoSellConfig.AutoSellEnabled = Options.AutoSellEnabled.Value
    if CONFIG.autoSellConfig.AutoSellEnabled then
        startMonitoring()
    else
        stopMonitoring()
    end
end)

local RarityMultiDropdown = Tabs.Shop:AddDropdown("RarityMultiDropdown", {
    Title = "Auto Sell Rarities",
    Description = "Select which rarities to auto sell",
    Values = {"Rare", "Epic", "Legendary"},
    Multi = true,
    Default = {},
})

RarityMultiDropdown:OnChanged(function(Value)
    CONFIG.autoSellConfig.Rare = false
    CONFIG.autoSellConfig.Epic = false
    CONFIG.autoSellConfig.Legendary = false

    for rarity, state in pairs(Value) do
        if state then
            if rarity == "Rare" then
                CONFIG.autoSellConfig.Rare = true
            elseif rarity == "Epic" then
                CONFIG.autoSellConfig.Epic = true
            elseif rarity == "Legendary" then
                CONFIG.autoSellConfig.Legendary = true
            end
        end
    end
end)

local OptimizerToggle = miscMainSection:AddToggle("OptimizerEnabled", { Title = "Enable Optimizer", Default = false })
OptimizerToggle:OnChanged(function()
    if Options.OptimizerEnabled.Value then
        optimizeGame()
        notify("Optimization Applied", "Optimizations activated")
    else
        restoreGame()
         notify("Optimization Disabled", "Optimizations disabled")
    end
end)

local FriendJoiner = friendSection:AddToggle("FriendJoinerEnabled", { Title = "Enable Friend Joiner", Description = "Must be used by ALT account",Default = false })
local FriendJoinName = friendSection:AddInput("Name", {
    Title = "Join Who?",
    Default = "",
    Numeric = false,
    Finished = false,
    Placeholder = "",
    Callback = function(Value)
       CONFIG.friendJoinerConfig.name = Value
    end
})
local FriendWaiter = friendSection:AddToggle("FriendWaiterEnabled", { Title = "Enable Friend Waiter", Description = "Must be used by MAIN account", Default = false })
local FriendWaitName = friendSection:AddInput("Name", {
    Title = "Wait Who?",
    Default = "",
    Numeric = false,
    Finished = false,
    Placeholder = "",
    Callback = function(Value)
       CONFIG.friendWaiterConfig.name = Value
    end
})
FriendJoiner:OnChanged(function()
     if Options.FriendJoinerEnabled.Value then
        if Options.FriendWaiterEnabled.Value then
            Options.FriendWaiterEnabled.Value = false
            FriendWaiter:SetValue(false)
        end
        startFollow()
    else
        stopFollow()
    end
end)
FriendWaiter:OnChanged(function()
    if Options.FriendWaiterEnabled.Value then
        if Options.FriendJoinerEnabled.Value then
            Options.FriendJoinerEnabled.Value = false
            FriendJoiner:SetValue(false)
        end
        CONFIG.joinerConfig.waitForFriend = true
        startWait()
    else
        CONFIG.joinerConfig.waitForFriend = false
        stopWait()
    end
end)
local ChallJoiner = autoJoinChallSection:AddToggle("JoinChallEnabled", {
    Title = "Enable Challenge Joiner",
    Description = "Auto Join Challenge",
    Default = false
})
ChallJoiner:OnChanged(function()
    CONFIG.joinerChallConfig.enabled = Options.JoinChallEnabled.Value
    if CONFIG.joinerChallConfig.enabled then
        startAutoChallenge()
    else
        stopAutoChallenge()
    end
end)

local challSelectChall = autoJoinChallSection:AddDropdown("SelectChallenge", {
    Title = "Select Challenge",
    Description = "Select which challenges to do",
    Values = getChallenges(),
    Multi = true,
    Default = {},
    Callback = function (Value)
        print(Value)
        CONFIG.joinerChallConfig.selectChall = {
            Value
        }
    end
})

local challSelectRew = autoJoinChallSection:AddDropdown("SelectReward", {
    Title = "Select Reward",
    Description = "Select which rewards to get",
    Values = getRewards(),
    Multi = true,
    Default = {},
    Callback = function (Value)
        print(Value)
        CONFIG.joinerChallConfig.selectRew = {
            Value
        }
    end
})

local challSelectWorld = autoJoinChallSection:AddDropdown("SelectWorld", {
    Title = "Select World",
    Description = "Select which worlds to do",
    Values = worldNames,
    Multi = true,
    Default = {},
    Callback = function (Value)
        print(Value)
        CONFIG.joinerChallConfig.selectWorld = {
            Value
        }
    end
})

local LegendJoiner = autoJoinLegenSection:AddToggle("JoinLegenEnabled", {
    Title = "Enable Auto Legend",
    Default = CONFIG.joinerLegendConfig.enabled,
    Callback = function(Value)
        CONFIG.joinerLegendConfig.enabled = Value
        if CONFIG.joinerLegendConfig.enabled then
           startJoinLegend()
        else
           stopJoinLegend()
        end
    end
})

local LegendSelectAct = autoJoinLegenSection:AddDropdown("SelectAct2", {
    Title = "Select Act",
    Description = "Pick an act to join",
    Values = {},
    Default = CONFIG.joinerLegendConfig.Act,
    Multi = false,
    Callback = function(Value)
        CONFIG.joinerLegendConfig.Act = WorldsLegend[CONFIG.joinerLegendConfig.World][Value]
    end
})

local LegendSelectWorld = autoJoinLegenSection:AddDropdown("SelectWorld2", {
    Title = "Select World",
    Description = "Pick a world to join",
    Values = worldNamesLegend,
    Default = CONFIG.joinerLegendConfig.World,
    Multi = false,
    Callback = function(Value)
        CONFIG.joinerLegendConfig.World = Value
        LegendSelectAct:SetValues(getLegends(CONFIG.joinerLegendConfig.World))
        CONFIG.joinerLegendConfig.Act = WorldsLegend[CONFIG.joinerLegendConfig.World]["Act 1"]
        LegendSelectAct:SetValue("Act 1")
    end
})

local RaidJoiner = autoJoinRaidSection:AddToggle("JoinRaidEnabled", {
    Title = "Enable Auto Raid",
    Default = CONFIG.joinerRaidConfig.enabled,
    Callback = function(Value)
        CONFIG.joinerRaidConfig.enabled = Value
        if CONFIG.joinerRaidConfig.enabled then
            startJoinRaid()
        else
            stopJoinRaid()
        end
    end
})

local RaidSelectAct = autoJoinRaidSection:AddDropdown("SelectAct3", {
    Title = "Select Act",
    Description = "Pick an act to join",
    Values = {},
    Default = CONFIG.joinerRaidConfig.Act,
    Multi = false,
    Callback = function(Value)
        CONFIG.joinerRaidConfig.Act = WorldsRaid[CONFIG.joinerRaidConfig.World][Value]
    end
})

local RaidSelectWorld = autoJoinRaidSection:AddDropdown("SelectWorld3", {
    Title = "Select World",
    Description = "Pick a world to join",
    Values = worldNamesRaid,
    Default = CONFIG.joinerRaidConfig.World,
    Multi = false,
    Callback = function(Value)
        CONFIG.joinerRaidConfig.World = Value
        RaidSelectAct:SetValues(getRaids(CONFIG.joinerRaidConfig.World))
        CONFIG.joinerRaidConfig.Act = WorldsRaid[CONFIG.joinerRaidConfig.World]["Act 1"]
        RaidSelectAct:SetValue("Act 1")
    end
})

local SelectMacro = macroRecorder:AddDropdown("SelectMacro",{
    Title = "Select Macro",
    Description = "Select Macro to Record/Play",
    Values = {},
    Default = "",
    Multi = false,
    Callback = function (Value)
        
    end
})

-- Update macro UI elements
local function refreshMacroList()
    local macros = listfiles(macroDirectory)
    local macroNames = {}
    
    for _, path in ipairs(macros) do
        if string.sub(path, -5) == ".json" then
            table.insert(macroNames, string.match(path, "([^/]+)%.json$"))
        end
    end
    
    SelectMacro:SetValues(macroNames)
end

local CreateMacro = macroRecorder:AddInput("CreateMacro",{
    Title = "Create Macro",
    Placeholder = "Enter name here..",
    Default = "",
    Finished = true,
    Callback = function (value)
        if value ~= "" then
            notify("Macro Created",value)
            saveMacro(value, {})
            refreshMacroList()
            CreateMacro:SetValue("")
        end
    end
})

local RecordMacro = macroRecorder:AddToggle("RecordMacro",{
    Title = "Record Macro",
    Default = false,
})

local PlayMacro = macroRecorder:AddToggle("PlayMacro",{
    Title = "Play Macro",
    Default = false,
})

RecordMacro:OnChanged(function(value)
    if not Options.SelectMacro or not Options.SelectMacro.Value then
        notify("Select a Macro","Unable to record...")
        RecordMacro:SetValue(false)
        return
    else
        if Options.PlayMacro.Value then
            notify("Turning off Macro to record..")
            PlayMacro:SetValue(false)
        else
            isRecording = value
            if value then
                macroStartTime = os.clock()
                logArray = {}
                notify("Recording Started",Options.SelectMacro.Value)
            else
                saveMacro(Options.SelectMacro.Value,logArray)
                notify("Recording Saved",Options.SelectMacro.Value)
                print("Recording stopped. Total actions:", #logArray)
            end
        end
    end
end)

PlayMacro:OnChanged(function(value)
    if not Options.SelectMacro or not Options.SelectMacro.Value then
        notify("Select a Macro", "Unable to play macro...")
        PlayMacro:SetValue(false)
        return
    else
        if Options.RecordMacro.Value then
            notify("Turning off Recorder to record.")
            RecordMacro:SetValue(false)
        else
            isMacroPlaying = value
            if value then
                if loadMacro(Options.SelectMacro.Value) then
                    notify("Playing Macro", Options.SelectMacro.Value)
                    playMacro()
                else
                    notify("Error Loading Macro", Options.SelectMacro.Value)
                end
            else
                notify("Macro Stopped", Options.SelectMacro.Value)
            end
        end
    end
end)

-- Initial refresh
refreshMacroList()

if game.PlaceId ~= CONSTANTS.TELEPORT_ID then
    local mt = getrawmetatable(game)
    local oldInvokeServer = mt.__namecall
    setreadonly(mt, false)
    
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "InvokeServer" then
            local remoteName = tostring(self)
            
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
end


-- Initialization Logic
AutoSellEnabledToggle:SetValue(CONFIG.autoSellConfig.AutoSellEnabled)
print("\n=== INITIAL UNIT SCAN ===")
processedUnits = {}
local initialCollection = ItemInventoryService.session.collection.collection_profile_data.owned_units
if initialCollection then
    for uniqueId, unitEntry in pairs(initialCollection) do
        if unitEntry and unitEntry.unit_id then
            processUnit(uniqueId, unitEntry)
        end
    end
end
if CONFIG.autoSellConfig.AutoSellEnabled then
    startMonitoring()
end

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/specific-game")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
notify("Lucifer", "The script has been loaded.")
SaveManager:LoadAutoloadConfig()