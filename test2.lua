-- Constants and Configurations
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
        lobby = "",
        selectWorld = {

        },
        selectChall = {
            
        },
        selectRew = {

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
local lockRemote = clientToServer:WaitForChild("request_lock_level")
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
for name in pairs(Worlds) do
    table.insert(worldNames, name)
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
    Joiner = Window:AddTab({ Title = "Joiner", Icon = "lucide-timer" }),
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

local shopMainSection = Tabs.Shop:AddSection("Auto Sell Configuration", 1)

local miscMainSection = Tabs.Misc:AddSection("Optimization Settings", 1)
local miscExtraSection = Tabs.Misc:AddSection("Other Utilities", 2)
local diagnosticsSection = Tabs.Misc:AddSection("Diagnostics", 3)

Tabs["Farm Config"]:AddSection("Combat Settings", 1)
Tabs["Farm Config"]:AddSection("Target Filters", 2)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
Window:SelectTab(1)

-- UI Variables
local autoJoining
local followingPLayer
local waitingPlayer
local autoChallenge
local teleportClickCount = 0
local isTeleporting = false
local friendIsIn = false

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
        if lobby and lobby:FindFirstChild("World") then
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

local function tableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
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
local function autoJoinWorld()
    while true do
        local currlob = findPlayerInLobbies(game.Players.LocalPlayer.Name)
        if currlob then
            lockInLevel()
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
            -- Handle rewards array
            if val.local_rewards and #val.local_rewards > 0 then
                local rewards = val.local_rewards[1].item
                for i, item in ipairs(rewards) do
                    currRew[i] = item.item_id
                end
            end
        elseif key:match("current_level_id") then
            currWorld = val
        elseif key:match("current_challenge") then
            currChal = val
        end
    end

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
    local info = getCurrentChallenge()
    local info2 = CONFIG.joinerChallConfig
    
    -- Check if ANY reward matches config
    local rewardCheck = false
    for _, rewardId in ipairs(info[2]) do
        if tableContains(info2.selectRew, rewardId) then
            rewardCheck = true
            break
        end
    end

    local startJoin = tableContains(info2.selectChall, info[1]) 
                   and rewardCheck 
                   and tableContains(info2.selectWorld, info[3])

    if startJoin then
        if checkChallengeCompletion() == false then
            --implement logic
        else
            print("Challenge is Completed!!!")
        end
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
local friendOnly = joinerSets:AddToggle("FriendsOnlyEnabled", {Title = "Friends Only?",Default = CONFIG.joinerConfig.friendOnly})

friendOnly:OnChanged(function(Value)
    CONFIG.joinerConfig.friendOnly = Value
end)

local leaveLobbyButton = autoJoinWorldSection:AddButton({
    Title = "Leave Current Lobby",
    Description = "Leave lobby",
    Callback = function()
        leaveLobbyy()
    end
})
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
local HardMode = autoJoinWorldSection:AddToggle("hardModeToggle", {
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
local challSelectChall = autoJoinChallSection:AddDropdown("SelectChallenge", {
    Title = "Select Challenge",
    Description = "Select which challenges to do",
    Values = getChallenges(),
    Multi = true,
    Default = {},
})

challSelectChall:OnChanged(function(Value)
    print(Value)
    CONFIG.joinerChallConfig.selectChall = {
        Value
    }
end)

local challSelectRew = autoJoinChallSection:AddDropdown("SelectReward", {
    Title = "Select Reward",
    Description = "Select which rewards to get",
    Values = getRewards(),
    Multi = true,
    Default = {},
})

challSelectRew:OnChanged(function(Value)
    print(Value)
    CONFIG.joinerChallConfig.selectRew = {
        Value
    }
end)

local challSelectWorld = autoJoinChallSection:AddDropdown("SelectWorld", {
    Title = "Select World",
    Description = "Select which worlds to do",
    Values = worldNames,
    Multi = true,
    Default = {},
})

challSelectWorld:OnChanged(function(Value)
    print(Value)
    CONFIG.joinerChallConfig.selectWorld = {
        Value
    }
end)

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