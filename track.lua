-- Load SimpleSpy
local success, err = pcall(function()
    getgenv().SimpleSpy = loadstring(game:HttpGet("https://raw.githubusercontent.com/exxtremestuffs/SimpleSpySource/master/SimpleSpy.lua"))()
end)

-- Check if SimpleSpy loaded
if not SimpleSpy or err then
    warn("SimpleSpy failed to load:", err)
    return
end

-- Fetch the RemoteFunction (DO NOT CALL IT YET)
local f = game:GetService("ReplicatedStorage").endpoints.client_to_server:WaitForChild("get_normal_challenge"):InvokeServer()

-- Use ValueToString on the RemoteFunction (not its return value)
local pathString = SimpleSpy:ValueToString(f)
print("Remote Path:", pathString) -- Should output the path to the RemoteFunction
