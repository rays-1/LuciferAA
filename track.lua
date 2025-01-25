local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local TARGET_PLAYER_NAME = "nicosoelbatobato" -- Case-sensitive
local CHECK_INTERVAL = 5 -- Seconds between checks
local DEBUG_MODE = true -- Set to false to disable print messages

-- Services
local endpoints = ReplicatedStorage:WaitForChild("endpoints"):WaitForChild("client_to_server")
local joinRemote = endpoints:WaitForChild("request_join_lobby")
local leaveRemote = endpoints:WaitForChild("request_leave_lobby")

-- State tracking
local currentLobby = nil
local lastValidLobby = nil

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

local function followPlayer()
    while true do
        task.wait(CHECK_INTERVAL)
        
        -- Find target player's lobby
        local targetLobby = findPlayerInLobbies(TARGET_PLAYER_NAME)
        
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

-- Start following
followPlayer()