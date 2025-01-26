local maxAttempts = 5

local function attemptLoad(url, attempts)
    for attempt = 1, attempts do
        local success, result = pcall(function()
            return loadstring(game:HttpGet(url))()
        end)
        if success then
            return result
        end
        if attempt == attempts then
            error("Failed to load resource after " .. attempts .. " attempts: " .. tostring(result))
        end
        task.wait(1)
    end
end

local Fluent = attemptLoad("https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/release.lua", maxAttempts)
local SaveManager = attemptLoad("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua", maxAttempts)
local InterfaceManager = attemptLoad("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua", maxAttempts)
local SimpleSpy = attemptLoad("https://github.com/exxtremestuffs/SimpleSpySource/raw/master/SimpleSpy.lua",maxAttempts)
local LuciferVer = "v0.0001"
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Loader
local autoSellConfig = {
    Rare = false,
    Epic = false,
    Legendary = false,
    Cooldown = 0.5,
    AutoSellEnabled = false
}
local currentLobby = nil
local lastValidLobby = nil

local friendJoinerConfig = {
    name = "",
}

local friendWaiterConfig = {
    name = ""
}


DEBUG_MODE = true
local processedUnits = {}
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
local ws = game:GetService("Workspace")
local optimized = false

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

local Worlds = {}

-- GET WORLD DATA
for _, moduleScript in ipairs(WorldsSrc:GetChildren()) do
    if moduleScript:IsA("ModuleScript") and moduleScript.Name ~= "Worlds_raids" and moduleScript.Name ~= "UnitPresets" then
        local worldData = require(moduleScript)
        
        for _, worldEntry in pairs(worldData) do
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

local worldNames = {}
for name in pairs(Worlds) do
    table.insert(worldNames, name)
end

local joinerConfig = {
    waitForFriend = false,
    enabled = false,
    friendOnly = false,
    lobby = "",
    hardMode = "Normal",
    worldJoinerConfig = {
        World = "Planet Greenie",
        Act = Worlds["Planet Greenie"]["Act 1"]
    }
}


local Window = Fluent:CreateWindow({
    Title = "Lucifer " .. LuciferVer,
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

local shopMainSection = Tabs.Shop:AddSection("Auto Sell Configuration", 1)

local miscMainSection = Tabs.Misc:AddSection("Optimization Settings", 1)
local miscExtraSection = Tabs.Misc:AddSection("Other Utilities", 2)

Tabs["Farm Config"]:AddSection("Combat Settings", 1)
Tabs["Farm Config"]:AddSection("Target Filters", 2)

Tabs.Misc:AddSection("Environment", 1)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

local autoJoining
local followingPLayer
local waitingPlayer
local teleportClickCount = 0
local teleportCooldown = 2
local isTeleporting = false
local friendIsIn = false
local ItemInventoryService
local success, err = pcall(function()
    ItemInventoryService = Loader.load_client_service(script, "ItemInventoryServiceClient")
end)
if not success or not ItemInventoryService then
    error("Failed to load ItemInventoryServiceClient: " .. tostring(err))
end

local teleportButton = MainActions:AddButton({
    Title = "Teleport to Lobby",
    Description = "Double-click to confirm",
    Callback = function()
        teleportClickCount = teleportClickCount + 1

        if teleportClickCount == 1 then
            task.delay(teleportCooldown, function()
                if teleportClickCount == 1 then
                    teleportClickCount = 0
                end
            end)
        elseif teleportClickCount >= 2 and not isTeleporting then
            isTeleporting = true

            Fluent:Notify({
                Title = "Attempt Teleport",
                Content = "Attempting to Teleport",
                Duration = 3
            })

            local TeleportService = game:GetService("TeleportService")
            local success, err = pcall(function()
                TeleportService:Teleport(8304191830, game.Players.LocalPlayer)
            end)

            if not success then
                Fluent:Notify({
                    Title = "Teleport Failed",
                    Content = "Error: " .. tostring(err),
                    Duration = 3
                })
            end

            teleportClickCount = 0
            isTeleporting = false
        end
    end
})

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

    if autoSellConfig[rarity] and autoSellConfig.AutoSellEnabled then
        local success, result = pcall(function()
            if processedUnits[uniqueId] then return end
            sellEndpoint:InvokeServer(args)
            processedUnits[uniqueId] = true
        end)

        if success then
            print(string.format("Sold %s (Rarity: %s)", unitName, rarity))
            processedUnits[uniqueId] = true
        else
            warn(string.format("Failed to sell %s: %s", unitName, tostring(result)))
        end
    else
        print(string.format("Keeping %s (Rarity: %s)", unitName, rarity))
        processedUnits[uniqueId] = true
    end

    if unitInfo.upgrade then
        local maxLevel = #unitInfo.upgrade
        local finalDamage = unitInfo.upgrade[maxLevel] and unitInfo.upgrade[maxLevel].damage or "N/A"
        print(string.format("  Can upgrade to: %s damage (Lvl %d)", finalDamage, maxLevel))
    end
end

local monitoringTask
local function monitorCollection()
    while task.wait(autoSellConfig.Cooldown) and autoSellConfig.AutoSellEnabled do
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
        if not autoSellConfig.AutoSellEnabled then break end
    end
end

local function findPlayerInLobbies(targetName)
    -- Check story/infinite/legend lobbies (1-9)
    for i = 1, 9 do
        local lobbyName = "_lobbytemplategreen" .. i
        local lobby = workspace._LOBBIES.Story:FindFirstChild(lobbyName)
        if lobby and lobby:FindFirstChild("World") then
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

    -- Check event lobbies
    local eventLobbies = {
        "_lobbytemplate_event3", -- Christmas
        "_lobbytemplate_event4"  -- Halloween
    }
    
    for _, lobbyName in ipairs(eventLobbies) do
        local lobby = workspace._EVENT_CHALLENGES.Lobbies:FindFirstChild(lobbyName)
        if lobby and lobby:FindFirstChild("World") then
            local playersFolder = lobby:FindFirstChild("Players")
            if playersFolder then
                for _, objValue in ipairs(playersFolder:GetChildren()) do
                    if tostring(objValue.Value) == targetName  then
                        return lobbyName
                    end
                end
            end
        end
    end

    return nil
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

local function optimizeGame()
    if optimized then return end
    optimized = true
    local camera = ws:WaitForChild("Camera")
    print("Optimization started...")

    for _, descendant in ipairs(game:GetDescendants()) do
        if descendant and not descendant:IsDescendantOf(camera) then
            -- Initialize property storage
            originalProperties[descendant] = originalProperties[descendant] or {}

            -- BasePart optimizations
            if descendant:IsA("BasePart") then
                originalProperties[descendant].Material = descendant.Material
                originalProperties[descendant].CastShadow = descendant.CastShadow
                descendant.Material = Enum.Material.Plastic
                descendant.CastShadow = false
            end

            -- Visual effects
            if descendant:IsA("Beam") or descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") then
                originalProperties[descendant].Enabled = descendant.Enabled
                descendant.Enabled = false
            end

            -- Mesh handling with safety checks
            if descendant:IsA("MeshPart") or descendant:IsA("SpecialMesh") then
                if pcall(function() return descendant.MeshId end) then
                    originalProperties[descendant].MeshId = descendant.MeshId
                    descendant.MeshId = ""
                end
                if pcall(function() return descendant.TextureId end) then
                    originalProperties[descendant].TextureId = descendant.TextureId
                    descendant.TextureId = ""
                end
            end

            -- Texture handling
            if descendant:IsA("Texture") then
                originalProperties[descendant].Texture = descendant.Texture
                descendant.Texture = ""
            end
        end
    end
end

local function restoreGame()
    if not optimized then return end
    print("Restoring original state...")
    
    for descendant, props in pairs(originalProperties) do
        if descendant and descendant.Parent then
            -- Restore BasePart properties
            if descendant:IsA("BasePart") then
                if props.Material then
                    descendant.Material = props.Material
                end
                if props.CastShadow ~= nil then
                    descendant.CastShadow = props.CastShadow
                end
            end

            -- Restore visual effects
            if descendant:IsA("Beam") or descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") then
                if props.Enabled ~= nil then
                    descendant.Enabled = props.Enabled
                end
            end

            -- Restore mesh properties
            if descendant:IsA("MeshPart") or descendant:IsA("SpecialMesh") then
                if props.MeshId and pcall(function() descendant.MeshId = props.MeshId end) then
                    descendant.MeshId = props.MeshId
                end
                if props.TextureId and pcall(function() descendant.TextureId = props.TextureId end) then
                    descendant.TextureId = props.TextureId
                end
            end

            -- Restore textures
            if descendant:IsA("Texture") then
                if props.Texture and pcall(function() descendant.Texture = props.Texture end) then
                    descendant.Texture = props.Texture
                end
            end
        end
    end
    
    optimized = false
    table.clear(originalProperties)
end

local function followPlayer()
    while true do
        task.wait(5)
        
        -- Find target player's lobby
        local targetLobby = findPlayerInLobbies(friendJoinerConfig.name)
        
        if targetLobby then
            if currentLobby == targetLobby then
                if DEBUG_MODE then
                    print("Already in correct lobby:", targetLobby)
                end
            else
                -- Leave current lobby if needed
                if currentLobby then
                    if DEBUG_MODE then
                        print("Leaving current lobby:", currentLobby)
                    end
                    local args = {
                        [1] = currentLobby
                    }
                    leaveRemote:InvokeServer(unpack(args))
                end

                -- Join new lobby
                if DEBUG_MODE then
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
            if DEBUG_MODE then
                print("Target player not found in any lobby")
            end
            -- Optionally return to last valid lobby
            -- if lastValidLobby then
            --     joinRemote:InvokeServer({[1] = lastValidLobby})
            -- end
        end
    end
end

local Timer = 60

local function lockInLevel()
    local args = {
        [1] = joinerConfig.lobby,
        [2] = joinerConfig.worldJoinerConfig.Act,
        [3] = joinerConfig.friendOnly,
        [4] = joinerConfig.hardMode
    }
    if joinerConfig.worldJoinerConfig.Act == "Infinite" then
        args[4] = "Hard"
    end

    game:GetService("ReplicatedStorage").endpoints.client_to_server.request_lock_level:InvokeServer(unpack(args))

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

    if freeLobby then
        local args = {
            [1] = freeLobby
        }
        joinRemote:InvokeServer(unpack(args))
    end
    task.wait()
    joinerConfig.lobby = freeLobby
end

local function waitPlayer()
    while friendIsIn ~= true do
        task.wait(2)
        local currentLobby = findPlayerInLobbies(game.Players.LocalPlayer.Name)
        if currentLobby then
            local lobby = workspace._LOBBIES.Story:FindFirstChild(currentLobby)
            local Timer = lobby:FindFirstChild("Timer")
            local playersFolder = lobby:FindFirstChild("Players")
            if playersFolder then
                for _, objValue in ipairs(playersFolder:GetChildren()) do
                    if tostring(objValue.Value) == friendWaiterConfig.name then
                        friendIsIn = true
                    end
                end
            end 
            if Timer.Value <= 10 then
                local args = {
                    [1] = currentLobby
                }
                leaveRemote:InvokeServer(unpack(args))
                joinRemote:InvokeServer(unpack(args))
            end
        else
            if joinerConfig.enabled then
                joinRandomLobby()
                lockInLevel()
            end
        end
    end
end



local function autoJoinWorld()
    joinRandomLobby()
    if joinerConfig.waitForFriend then
        lockInLevel()
        waitPlayer()
    else
        lockInLevel()
    end
end

local function startJoin()
    if autoJoining then
        task.cancel(autoJoining)
        autoJoining = nil
    end
    autoJoining = task.spawn(autoJoinWorld)
    print("\n=== AUTO-JOIN SYSTEM ACTIVATED ===")
end

local function stopJoin()
    if autoJoining then
        task.cancel(autoJoining)
        autoJoining = nil
    end
    print("\n=== AUTO-JOIN SYSTEM DEACTIVATED ===")
end

local function startFollow()
    if followingPLayer then
        task.cancel(followingPLayer)
        followingPLayer = nil
    end
    followingPLayer = task.spawn(followPlayer)
    print("\n=== AUTO-FOLLOW SYSTEM ACTIVATED ===")
end

local function stopFollow()
    if followingPLayer then
        task.cancel(followingPLayer)
        followingPLayer = nil
    end
    print("\n=== AUTO-FOLLOW SYSTEM DEACTIVATED ===")
end

local function startWait()
    if waitingPlayer then
        task.cancel(waitingPlayer)
        waitingPlayer = nil
    end
    waitingPlayer = task.spawn(waitPlayer)
    print("\n=== AUTO-WAIT SYSTEM ACTIVATED ===")
end

local function stopWait()
    if waitingPlayer then
        task.cancel(waitingPlayer)
        waitingPlayer = nil
    end
    print("\n=== AUTO-WAIT SYSTEM DEACTIVATED ===")
end

local function getActsForWorld(worldName)
    local worldData = Worlds[worldName]
    local acts = {}
    for key in pairs(worldData) do
        if key:match("Act %d") then -- Match "Act" followed by a number
            table.insert(acts, key)
        end
    end
    acts["Infinite"] = worldData.Infinite
    table.sort(acts)
    return acts
end


local Options = Fluent.Options

local friendOnly = joinerSets:AddToggle("FriendsOnlyEnabled", {Title = "Friends Only?",Default = joinerConfig.friendOnly})

friendOnly:OnChanged(function(Value)
    joinerConfig.friendOnly = Value
end)


local autoJoinEnable = autoJoinWorldSection:AddToggle("autoJoinEnable", {
    Title = "Enable Auto Join",
    Default = joinerConfig.enabled,
    Callback = function(Value)
        joinerConfig.enabled = Value
        if joinerConfig.enabled then
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
           joinerConfig.hardMode = "Hard" 
        else
            joinerConfig.hardMode = "Normal"
        end
    end
})
-- Fix the world section dropdown
local actSection = autoJoinWorldSection:AddDropdown("actPicker", {
    Title = "Select Act",
    Description = "Pick an act to join",
    Values = getActsForWorld(joinerConfig.worldJoinerConfig.World),
    Default = Worlds[joinerConfig.worldJoinerConfig.World]["Act 1"],
    Multi = false,
    Callback = function(Value)  
        joinerConfig.worldJoinerConfig.Act = Worlds[joinerConfig.worldJoinerConfig.World][Value]
    end
})

local worldSection = autoJoinWorldSection:AddDropdown("worldPicker", {
    Title = "Auto Join World",
    Description = "Pick a world to join",
    Values = worldNames,
    Default = "Planet Greenie",
    Multi = false,
    Callback = function(Value)
        joinerConfig.worldJoinerConfig.World = Value
        -- Update act dropdown when world changes
    end
})
-- Fix the act section dropdown

local AutoSellEnabledToggle = shopMainSection:AddToggle("AutoSellEnabled", {
    Title = "Enable Auto Sell",
    Default = autoSellConfig.AutoSellEnabled
})


AutoSellEnabledToggle:OnChanged(function()
    autoSellConfig.AutoSellEnabled = Options.AutoSellEnabled.Value
    if autoSellConfig.AutoSellEnabled then
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
    autoSellConfig.Rare = false
    autoSellConfig.Epic = false
    autoSellConfig.Legendary = false

    for rarity, state in pairs(Value) do
        if state then
            if rarity == "Rare" then
                autoSellConfig.Rare = true
            elseif rarity == "Epic" then
                autoSellConfig.Epic = true
            elseif rarity == "Legendary" then
                autoSellConfig.Legendary = true
            end
        end
    end
end)

local OptimizerToggle = miscMainSection:AddToggle("OptimizerEnabled", { Title = "Enable Optimizer", Default = false })
OptimizerToggle:OnChanged(function()
    if Options.OptimizerEnabled.Value then
        optimizeGame()
        Fluent:Notify({
            Title = "Optimization Applied",
            Content = "Optimizations activated",
            Duration = 3
        })
    else
        restoreGame()
        Fluent:Notify({
            Title = "Optimization Disabled",
            Content = "Optimizations disabled",
            Duration = 3
        })
    end
end)


--FRIEND JOIN AND WAIT
local FriendJoiner = friendSection:AddToggle("FriendJoinerEnabled", { Title = "Enable Friend Joiner", Description = "Must be used by MAIN account",Default = false })
local FriendWaiter = friendSection:AddToggle("FriendWaiterEnabled", { Title = "Enable Friend Waiter", Description = "Must be used by ALT account", Default = false })
local FriendJoinName = friendSection:AddInput("Name", {
    Title = "Join Who?",
    Default = "",
    Numeric = false,
    Finished = false,
    Placeholder = "",
    Callback = function(Value)
        friendJoinerConfig.name = Value
    end
})
local FriendWaitName = friendSection:AddInput("Name", {
    Title = "Wait Who?",
    Default = "",
    Numeric = false,
    Finished = false,
    Placeholder = "",
    Callback = function(Value)
        friendWaiterConfig.name = Value
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
        joinerConfig.waitForFriend = true
        startWait()
    else
        joinerConfig.waitForFriend = false
        stopWait()
    end
end)



AutoSellEnabledToggle:SetValue(autoSellConfig.AutoSellEnabled)

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
if autoSellConfig.AutoSellEnabled then
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

Fluent:Notify({
    Title = "Lucifer",
    Content = "The script has been loaded.",
    Duration = 8
})

SaveManager:LoadAutoloadConfig()
