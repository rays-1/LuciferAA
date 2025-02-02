local replicatedStorage = game:GetService("ReplicatedStorage")
local clientToServerFolder = replicatedStorage.endpoints.client_to_server

-- Recursive function to print a table
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

-- Function to test and log RemoteFunction responses
local function testRemoteFunction(remoteFunction)
    local success, result = pcall(function()
        -- Call the RemoteFunction with some dummy arguments (adjust as needed)
        local response = remoteFunction:InvokeServer("dummyArg1", "dummyArg2")
        print("RemoteFunction:", remoteFunction.Name)
        if type(response) == "table" then
            print("Returned Table:")
            printTable(response)
        else
            print("Returned:", response)
        end
    end)

    if not success then
        print("Error invoking RemoteFunction:", remoteFunction.Name, result)
    end
end

-- List of RemoteFunctions to test
local remoteFunctionNames = {
    "get_lobby_more_params",
    -- "request_current_gold_shop", --gold shop
    -- "request_current_madoka_shop", --event quest shop
    -- "request_current_raidshop_shop" --raid shop
    -- "poll_active_items" -- bulma shop
}

-- Loop through all RemoteFunctions in the folder
for _, child in pairs(clientToServerFolder:GetChildren()) do
    -- Check if the RemoteFunction is in the list
    if table.find(remoteFunctionNames, child.Name) then
        if child:IsA("RemoteFunction") then
            testRemoteFunction(child)
        end
    end
end


local remoteHooks = {}
local originalEvent, originalFunction

local remoteEvent = Instance.new("RemoteEvent")
local remoteFunction = Instance.new("RemoteFunction")

-- Hook function for RemoteEvents
local function newFireServer(remote, ...)
    if remoteHooks[remote] then
        local args = {...}
        args = {remoteHooks[remote](unpack(args))}
        return originalEvent(remote, unpack(args))
    end
    return originalEvent(remote, ...)
end

-- Hook function for RemoteFunctions
local function newInvokeServer(remote, ...)
    if remoteHooks[remote] then
        local args = {...}
        args = {remoteHooks[remote](unpack(args))}
        return originalFunction(remote, unpack(args))
    end
    return originalFunction(remote, ...)
end

-- Main hook function
function HookRemote(remote, func)
    if typeof(remote) == "Instance" and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
        remoteHooks[remote] = func
    end
end

HookRemote(buyBannerRemote, function(...)
    local args = {...}
    print("here!")
    return unpack(args)
end)