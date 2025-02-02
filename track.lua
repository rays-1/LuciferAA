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
    "request_current_raid_shop" 
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