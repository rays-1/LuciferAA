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

local UnitData = require(ReplicatedStorage.src.Data.Units)
local processedUnits = {}
local endpoints = ReplicatedStorage:WaitForChild("endpoints")
local sellEndpoint = endpoints:WaitForChild("client_to_server"):WaitForChild("sell_units")

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

Tabs.Farm:AddSection("Auto Farming", 1)
Tabs.Farm:AddSection("Loot Collection", 2)

Tabs.Joiner:AddSection("Lobby Selection", 1)
Tabs.Joiner:AddSection("Matchmaking", 2)

Tabs["Farm Config"]:AddSection("Combat Settings", 1)
Tabs["Farm Config"]:AddSection("Target Filters", 2)

Tabs.Misc:AddSection("Character Mods", 1)
Tabs.Misc:AddSection("Environment", 2)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

local teleportClickCount = 0
local teleportCooldown = 2
local isTeleporting = false
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
        teleportClickCount += 1

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
            continue
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

local havprop = pcall(function(ins,prop)
    local prop = ins.prop
end)

local function optimizeGame()
    if optimized then return end
    optimized = true
    local count = 0;
    print("reaching here..")
    for _, descendant in ipairs(game:GetDescendants()) do
        print("descendant")
        if descendant then
            print("--"..count)
            count = count + 1
            if descendant and  descendant:IsA("BasePart") then
                descendant.Material = Enum.Material.Plastic
                descendant.CastShadow = false
            end
            if descendant and descendant:IsA("Beam") or descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") then
                if descendant.Enabled then
                    local enabled = descendant.Enabled
                    if enabled then
                        originalProperties[descendant] = { enabled = enabled }
                        descendant.Enabled = false
                    end
                end
            end
            if descendant and descendant:IsA("MeshPart") or descendant:IsA("SpecialMesh") then
                if descendant.MeshId then
                    local meshId = descendant.MeshId
                    if meshId then
                        originalProperties[descendant].MeshId = meshId
                        descendant.MeshId = ""
                    end
                end
                if descendant.TextureId then
                    local textureId = descendant.TextureId
                    if textureId then
                        originalProperties[descendant].TextureId = textureId
                        descendant.TextureId = ""
                    end
                end
            end
            if  descendant and descendant:IsA("Texture") then
                local Texture = descendant.Texture;
                if Texture then
                    descendant.Texture = ""
                    originalProperties[descendant] = {Texture = Texture}
                end
            end
        else
            print("eep")
        end
    end
end

local function restoreGame()
    if not optimized then return end
    for descendant, originalState in pairs(originalProperties) do
        if descendant and descendant:IsA("Beam") or descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") then
            if originalState and originalState.enabled then
                descendant.Enabled = originalState.enabled
            end
        end
        if descendant and descendant:IsA("MeshPart") or descendant:IsA("SpecialMesh") then
            if originalState and originalState.MeshId then
                descendant.MeshId = originalState.MeshId
            end
            if originalState and originalState.TextureId then
                descendant.TextureId = originalState.TextureId
            end
        end
        if descendant and descendant:IsA("Texture")  then
            if originalState and originalState.Texture then
                descendant.Texture = originalState.Texture
            end
        end
    end
    optimized = false
end

local Options = Fluent.Options

local AutoSellEnabledToggle = Tabs.Shop:AddToggle("AutoSellEnabled", { Title = "Enable Auto Sell", Default = autoSellConfig.AutoSellEnabled })
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

local OptimizerToggle = Tabs.Misc:AddToggle("OptimizerEnabled", { Title = "Enable Optimizer", Default = false })
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
