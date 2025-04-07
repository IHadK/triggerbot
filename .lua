local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/SkibidiHack/StarHook-UILibrary/main/Library.lua"))();
local ui = {
    window = nil,
    tabs = {}
}
local window = library:New({
    Size = UDim2.new(0, 490, 0, 450)
});
local flags = library.Flags
local watermark = library:Watermark({Name = "zorski & josh triggerbot", Enabled = true, Position = UDim2.new(0, 0, 0, 0), Color = Color3.fromRGB(255, 255, 255)});

window:Seperator({Name = "josh's triggerbot wip"})

ui.tabs["legit"] = window:Page({Name = "josh's triggerbot", Icon = "http://www.roblox.com/asset/?id=6023426921"});
local triggerbotSection = ui.tabs["legit"]:Section({Name = "Triggerbot", Side = "Left", Size = 120});

local main_toggle = triggerbotSection:Toggle({Name = "Enabled", Flag = "tb_enabled"});
triggerbotSection:Keybind({Flag = "tb_keybind", Name = "toggle", Default = Enum.KeyCode.T, Mode = "Toggle"});
triggerbotSection:Slider({Name = "Delay", Flag = "tb_delay", Default = 1, Minimum = 1, Maximum = 300, Decimals = 1, Ending = "ms"});
--fov
local fovSection = ui.tabs["legit"]:Section({Name = "Field of View", Side = "Right", Size = 170});
fovSection:Colorpicker({Name = "FOV Color", Flag = "fov_color", Default = Color3.new(0, 1, 0)}); -- Note: Color3 values are 0-1
fovSection:Toggle({Name = "Visualize FOV", Flag = "fov_vis", Default = true});
fovSection:Slider({Name = "FOV Radius", Flag = "fov_radius", Default = 10, Minimum = 5, Maximum = 100, Decimals = 1, Ending = "px"});
fovSection:Slider({Name = "FOV Transparency", Flag = "fov_transparency", Default = 0, Minimum = 0, Maximum = 1, Decimals = 0.01, Ending = "%"});


-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Local variables
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

-- Debug logging
local function DebugLog(message)
    -- Format with brackets for easy censoring if needed
    print("[DEBUG] " .. message)
end

-- FOV Circle Drawing
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.NumSides = 100
FOVCircle.Filled = false

-- Mouse position handling
local function GetMousePosition()
    return UserInputService:GetMouseLocation()
end

-- Function to update FOV circle properties based on UI settings
local function UpdateFOVCircle()
    if flags.fov_vis and not flags.tb_keybind then
        FOVCircle.Visible = true
        FOVCircle.Radius = flags.fov_radius
        FOVCircle.Color = flags.fov_color
        FOVCircle.Transparency = 1 - flags.fov_transparency
        
        -- Get mouse position directly from UserInputService instead of Mouse object
        local mousePos = GetMousePosition()
        FOVCircle.Position = mousePos
    else
        FOVCircle.Visible = false
    end
end


-- Function to check if a player is within FOV
local function IsInFOV(player)
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    -- Get player's screen position
    local hrp = player.Character.HumanoidRootPart
    local vector, onScreen = Camera:WorldToScreenPoint(hrp.Position)
    
    if not onScreen then
        return false
    end
    
    -- Calculate distance between mouse and player on screen
    local mousePos = GetMousePosition()
    local playerPos = Vector2.new(vector.X, vector.Y)
    local distance = (mousePos - playerPos).Magnitude
    
    -- Check if within FOV radius
    return distance <= flags.fov_radius
end

-- Simplified wall check function (line of sight)
local function HasLineOfSight(player)
    if not player or not player.Character then
        return false
    end
    
    local character = player.Character
    local head = character:FindFirstChild("Head")
    
    if not head then
        return false
    end
    
    -- Raycast to check for obstructions
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    local direction = (head.Position - Camera.CFrame.Position).Unit
    local result = workspace:Raycast(Camera.CFrame.Position, direction * 1000, rayParams)
    
    if result and result.Instance and result.Instance:IsDescendantOf(character) then
        return true
    end
    
    return false
end

-- Function to find players in FOV
local function GetPlayersInFOV()
    local validPlayers = {}
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsInFOV(player) and HasLineOfSight(player) then
            table.insert(validPlayers, player)
        end
    end
    
    -- Debug log
    if #validPlayers > 0 then
        DebugLog("Detected " .. #validPlayers .. " players in FOV")
        for i, player in ipairs(validPlayers) do
            DebugLog("Player " .. i .. ": " .. player.Name)
        end
    end
    
    return validPlayers
end

-- Function to get closest player from a list
local function GetClosestPlayer(playerList)
    if #playerList == 0 then
        return nil
    end
    
    local closestPlayer = nil
    local shortestDistance = math.huge
    
    for _, player in ipairs(playerList) do
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local distance = (character.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
            if distance < shortestDistance then
                closestPlayer = player
                shortestDistance = distance
            end
        end
    end
    
    if closestPlayer then
        DebugLog("Targeting closest player: " .. closestPlayer.Name .. " (Distance: " .. math.floor(shortestDistance) .. ")")
    end
    
    return closestPlayer
end

-- Simulated mouse click
local function SimulateMouseClick()
    -- Store current mouse position before click
    local mouseX, mouseY = Mouse.X, Mouse.Y
    
    -- Press and release left mouse button
    VirtualInputManager:SendMouseButtonEvent(mouseX, mouseY, 0, true, game, 1)
    wait(0.01) -- Small delay between press and release
    VirtualInputManager:SendMouseButtonEvent(mouseX, mouseY, 0, false, game, 1)
    
    DebugLog("Mouse click simulated")
end

-- Main triggerbot loop
local lastShotTime = 0
local isMouseDown = false

-- Connect to input events to track mouse state
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isMouseDown = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isMouseDown = false
    end
end)

-- Main loop
RunService.RenderStepped:Connect(function()
    -- Update FOV circle
    UpdateFOVCircle()
    
    -- Only run if triggerbot is enabled and keybind is not toggled
    if flags.tb_enabled and not flags.tb_keybind then
        local currentTime = tick()
        local delayInSeconds = flags.tb_delay / 1000 -- Convert ms to seconds
        
        -- Check if we can shoot based on delay and if mouse is not already down
        if currentTime - lastShotTime >= delayInSeconds and not isMouseDown then
            local playersInFOV = GetPlayersInFOV()
            local targetPlayer = GetClosestPlayer(playersInFOV)
            
            if targetPlayer then
                DebugLog("Firing at: " .. targetPlayer.Name)
                lastShotTime = currentTime
                SimulateMouseClick()
            end
        end
    end
end)


-- Clean up when script stops
local onScriptEnd = function()
    if FOVCircle then
        FOVCircle:Remove()
    end
end

-- Handle script cleanup
game:BindToClose(onScriptEnd)

-- Return our functions for external use if needed
return {
    IsInFOV = IsInFOV,
    GetPlayersInFOV = GetPlayersInFOV,
    UpdateFOVCircle = UpdateFOVCircle
}
