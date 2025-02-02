-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Remotes to watch
local spawnUnitRemote = ReplicatedStorage.endpoints.client_to_server.spawn_unit
local upgradeUnitRemote = ReplicatedStorage.endpoints.client_to_server.upgrade_unit_ingame
local sellUnitRemote = ReplicatedStorage.endpoints.client_to_server.sell_unit_ingame

-- Table to store recorded macro data
local recordedMacro = {}

-- Flag to indicate recording status
local isRecording = false

-- Function to get player money (replace with your game's implementation)
local function getPlayerMoney()
    local leaderstats = game.Players.LocalPlayer:WaitForChild("leaderstats")
    local money = leaderstats:FindFirstChild("Money")
    return money and money.Value or 0
end

-- Function to add an entry to the recorded macro
local function recordMacroEntry(entry)
    table.insert(recordedMacro, entry)
end

-- Hook Spawn Unit Remote
spawnUnitRemote.OnClientInvoke = function(...)
    local args = {...}
    if isRecording then
        local uuid = args[1]
        local cframe = tostring(args[2]) -- Convert CFrame to string for serialization

        -- Record the spawn event
        recordMacroEntry({
            type = "spawn_unit",
            unit = uuid,
            cframe = cframe,
            money = getPlayerMoney()
        })
    end
    return unpack(args) -- Pass the original arguments back
end

-- Hook Upgrade Unit Remote
upgradeUnitRemote.OnClientInvoke = function(...)
    local args = {...}
    if isRecording then
        local unit = args[1]
        local uuid = unit:GetAttribute("_SPAWN_UNIT_UUID") -- Extract UUID from attributes

        -- Record the upgrade event
        recordMacroEntry({
            type = "upgrade_unit_ingame",
            unit = uuid,
            money = getPlayerMoney()
        })
    end
    return unpack(args)
end

-- Hook Sell Unit Remote
sellUnitRemote.OnClientInvoke = function(...)
    local args = {...}
    if isRecording then
        local unit = args[1]
        local uuid = unit:GetAttribute("_SPAWN_UNIT_UUID") -- Extract UUID from attributes

        -- Record the sell event
        recordMacroEntry({
            type = "sell_unit_ingame",
            unit = uuid,
            money = getPlayerMoney()
        })
    end
    return unpack(args)
end

-- Function to save recorded macro as JSON
local function saveMacroToJson()
    local jsonData = HttpService:JSONEncode(recordedMacro)
    print("Recorded Macro (JSON):")
    print(jsonData)
    
    -- Optionally, write to a file if running locally
    -- (This part only works in environments with file system access, e.g., Synapse X)
    if isfile then
        writefile("macro.json", jsonData)
        print("Macro saved to macro.json")
    end
end

-- Function to start recording
local function startRecording()
    if isRecording then
        warn("Already recording!")
        return
    end
    isRecording = true
    recordedMacro = {} -- Clear previous data
    print("Started recording macro...")
end

-- Function to stop recording
local function stopRecording()
    if not isRecording then
        warn("Not currently recording!")
        return
    end
    isRecording = false
    print("Stopped recording macro.")
    saveMacroToJson()
end

-- Bind chat commands to control recording
game.Players.LocalPlayer.Chatted:Connect(function(msg)
    if msg == "/startmacro" then
        startRecording()
    elseif msg == "/stopmacro" then
        stopRecording()
    end
end)

print("Macro recorder loaded. Use /startmacro and /stopmacro to control recording.")