local maxAttempts = 5

-- Function to load and execute a script
local function loadAndExecute(url, moduleName)
    print("Attempting to download " .. moduleName .. "...")
    local loadedModule

    for attempt = 1, maxAttempts do
        local success, result = pcall(function()
            loadedModule = loadstring(game:HttpGet(url))()
        end)

        if success then
             print(moduleName .. " downloaded successfully.")
            return loadedModule
        else
            warn("Failed to load " .. moduleName .. " (Attempt " .. attempt .. "): " .. tostring(result))
            if attempt == maxAttempts then
                error("Failed to load " .. moduleName .. " after " .. maxAttempts .. " attempts: " .. tostring(result))
             end
             task.wait(1)
        end
    end
    
   error("Failed to load" .. moduleName .. " after multiple attempts.")
end

-- Load Fluent
local Fluent
Fluent = loadAndExecute("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua", "Fluent")

-- Load SaveManager
local SaveManager
SaveManager = loadAndExecute("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua", "SaveManager")

-- Load InterfaceManager
local InterfaceManager
InterfaceManager = loadAndExecute("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua", "InterfaceManager")
   
print("All external libraries have been successfully loaded.")


local LuciferVer = "v0.0001"
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Loader
local autoSellConfig = {
    Rare = false,
    Epic = false,
    Legendary = false,
    Cooldown = .5,
    AutoSellEnabled = false
}
-- Track processed units
local UnitData = require(ReplicatedStorage.src.Data.Units)
local processedUnits = {}
local endpoints = ReplicatedStorage:WaitForChild("endpoints")
local sellEndpoint = endpoints:WaitForChild("client_to_server"):WaitForChild("sell_units")
-- Optimization Functions
local originalProperties = {}
local ws = game:GetService("Workspace")
local optimized = false


-- Loader
local loadLoader
for attempt = 1, maxAttempts do
 local success, result = pcall(function()
     loadLoader = require(ReplicatedStorage.src.Loader)
 end)
 if success then
  Loader = loadLoader
    break
  end
 if attempt == maxAttempts then
    error("Failed to load Loader after " .. maxAttempts .. " attempts: " .. tostring(result))
    end
    task.wait(1)
end
print("Loader module has been successfully loaded")

-- SimpleSpy initialization (use with caution)
if not SimpleSpy then
    local success, err = pcall(function()
        loadstring(game:HttpGet("https://github.com/exxtremestuffs/SimpleSpySource/raw/master/SimpleSpy.lua"))()
    end)
    if not success then
        warn("Failed to load SimpleSpy: " .. tostring(err))
    end
end


--aw
local Window = Fluent:CreateWindow({
    Title = "Lucifer " .. LuciferVer,
    SubTitle = "Made by Haro",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})
print("Fluent window has been successfully created.")

-- Create All Tabs
local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "home" }),
    Farm = Window:AddTab({ Title = "Farm", Icon = "activity" }),
    Joiner = Window:AddTab({ Title = "Joiner", Icon = "lucide-timer" }),
    ["Farm Config"] = Window:AddTab({ Title = "Farm Config", Icon = "settings" }),
    Shop = Window:AddTab({ Title = "Shop", Icon = "shopping-cart" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "box" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- Main Tab Sections
local MainWelcome = Tabs.Main:AddSection("Welcome to Lucifer", 1)
local MainActions = Tabs.Main:AddSection("Quick Actions", 2)

-- Farm Tab Sections
Tabs.Farm:AddSection("Auto Farming", 1)
Tabs.Farm:AddSection("Loot Collection", 2)

-- Joiner Tab Sections
Tabs.Joiner:AddSection("Lobby Selection", 1)
Tabs.Joiner:AddSection("Matchmaking", 2)

-- Farm Config Tab Sections
Tabs["Farm Config"]:AddSection("Combat Settings", 1)
Tabs["Farm Config"]:AddSection("Target Filters", 2)

-- Shop Tab Sections
-- Tabs.Shop:AddSection("Auto Purchases", 1) -- Removed existing section
-- Tabs.Shop:AddSection("Item Priority", 2) -- Removed existing section

-- Misc Tab Sections
Tabs.Misc:AddSection("Character Mods", 1)
Tabs.Misc:AddSection("Environment", 2)

-- Settings Tab (Required for Save/Load)
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
print("Fluent tabs have been successfully created.")

-- Add Teleport Button to Quick Actions section
-- Add to your Main tab sections
local teleportClickCount = 0
local teleportCooldown = 2 -- seconds between clicks
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

    local args = { tostring(uniqueId) }

    if autoSellConfig[rarity] and autoSellConfig.AutoSellEnabled then
        local success, result = pcall(function()
            if processedUnits[uniqueId] then return end
            sellEndpoint:InvokeServer(args)
            processedUnits[uniqueId] = true
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


local function optimizeGame()
    if optimized then return end
    optimized = true
    for _, descendant in ipairs(game:GetDescendants()) do
        if not descendant:IsDescendantOf(ws:WaitForChild("Camera") then
            if descendant:IsA("BasePart") then
                descendant.Material = Enum.Material.Plastic
            end
            if descendant:IsA("BasePart") or descendant:IsA("MeshPart") or descendant:IsA("Part") then
                if descendant.CastShadow then
                    local castShadow = descendant.CastShadow
                    if castShadow then
                        originalProperties[descendant] = {castShadow=castShadow}
                        descendant.CastShadow = false
                    end
                end
            elseif descendant:IsA("Beam") or descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") then
                if descendant.Enabled then
                    local enabled = descendant.Enabled
                    if enabled then
                        originalProperties[descendant] = {enabled=enabled}
                        descendant.Enabled = false
                    end
                end
            elseif descendant:IsA("MeshPart") or descendant:IsA("SpecialMesh") then
                if descendant.MeshId and descendant.TextureId then
                    local meshId = descendant.MeshId
                    local textureID = descendant.TextureID
                    if meshId and textureID then
                        originalProperties[descendant] = {MeshID=meshId,TextureID = textureID}
                        descendant.MeshId = ""
                        descendant.TextureId = ""
                    end
                end
            elseif descendant:IsA("BillboardGui") then
                if descendant.Enabled then
                    local enabled = descendant.Enabled
                    if enabled then
                        originalProperties[descendant] = {enabled = enabled}
                        descendant.Enabled = false
                    end
                end
            end
        end
    end
end

local function restoreGame()
    if not optimized then return end
    for descendant, originalState in pairs(originalProperties) do
        if descendant:IsA("BasePart") or descendant:IsA("MeshPart") then
            if originalState and originalState.castShadow then
                descendant.CastShadow = originalState.castShadow
            end
        elseif descendant:IsA("Beam") or descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") then
            if originalState and originalState.enabled then
                descendant.Enabled = originalState.enabled
            end
        elseif descendant:IsA("MeshPart") or descendant:IsA("SpecialMesh") then
            if originalState and originalState.MeshID then
                descendant.MeshId= originalState.MeshID
                descendant.TextureId= originalState.TextureID
            end
        elseif descendant:IsA("BillboardGui") then
            if originalState and originalState.enabled then
                descendant.Enabled = originalState.enabled
            end
        end
    end
    optimized = false
end

local Options = Fluent.Options


-- UI Elements for Auto-Sell in Shop Tab
local AutoSellEnabledToggle = Tabs.Shop:AddToggle("AutoSellEnabled", { Title = "Enable Auto Sell", Default = autoSellConfig.AutoSellEnabled })
AutoSellEnabledToggle:OnChanged(function()
    autoSellConfig.AutoSellEnabled = Options.AutoSellEnabled.Value
    if autoSellConfig.AutoSellEnabled then
        startMonitoring()
    else
        stopMonitoring()
    end
end)

    -- Add multi-select dropdown for rarities
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

-- Constant cooldown (no slider)
autoSellConfig.Cooldown = 0.5

-- Add optimizer toggle
local OptimizerToggle = Tabs.Misc:AddToggle("OptimizerEnabled", {Title = "Enable Optimizer", Default = false})
OptimizerToggle:OnChanged(function()
    if Options.OptimizerEnabled.Value then
        optimizeGame()
        Fluent:Notify({
            Title = "Optimization Applied",
            Content = "optimizations activated",
            Duration = 3
        })
    else
        restoreGame()
        Fluent:Notify({
            Title = "Optimization Disabled",
            Content = "optimizations Disabled",
            Duration = 3
        })
    end
end)

-- Update toggle for current state
AutoSellEnabledToggle:SetValue(autoSellConfig.AutoSellEnabled)
print("UI elements created")

-- Initial scan
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
print("Initial collection scanned")

-- Addons:
-- SaveManager (Allows you to have a configuration system)
-- InterfaceManager (Allows you to have a interface managment system)

-- Hand the library over to our managers
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

-- Ignore keys that are used by ThemeManager.
-- (we dont want configs to save themes, do we?)
SaveManager:IgnoreThemeSettings()

-- You can add indexes of elements the save manager should ignore
SaveManager:SetIgnoreIndexes({})

-- use case for doing it this way:
-- a script hub could have themes in a global folder
-- and game configs in a separate folder per game
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/specific-game")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
print("Managers have been setup")

Fluent:Notify({
    Title = "Lucifer",
    Content = "The script has been loaded.",
    Duration = 8
})

-- You can use the SaveManager:LoadAutoloadConfig() to load a config
-- which has been marked to be one that auto loads!
SaveManager:LoadAutoloadConfig()
print("Script has completed its loading process")