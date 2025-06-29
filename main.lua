-- Version 5

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

local AUTO_ACTIVATE = true
local MAX_DISTANCE = 15
local ACTIVATION_DELAY = 0.1

local BRAINROT_NAMES_URL = "https://raw.githubusercontent.com/SPIRALRBX-end/steal/refs/heads/main/return/brainrot_names.lua"

local trackedPrompts = {}
local lastActivation = {}
local connections = {}
local targetNames = {}

local function loadBrainrotNames()
    print("🌐 Loading Brainrot name list...")
    
    local success, result = pcall(function()
        local loadstring_func = loadstring or load
        if loadstring_func then
            local code = game:HttpGet(BRAINROT_NAMES_URL)
            local namesList = loadstring_func(code)()
            return namesList
        else
            error("Loadstring not available")
        end
    end)
    
    if success and result and type(result) == "table" then
        targetNames = result
        print("✅ List loaded successfully! Total names:", #targetNames)
        for i, name in pairs(targetNames) do
            print("  " .. i .. ". " .. name)
        end
        return true
    else
        print("⚠️ Failed to load online list, using local list instead...")
        targetNames = {
            "La Vacca Saturno Saturnita",
            "Los Tralaleritos", 
            "Graipuss Medussi",
            "La Grande Combinasion",
            "Matteo",
            "Trenostruzzo Turbo 3000",
            "Odin Din Din Dun",
            "Gattatino Nyanino"
        }
        print("📋 Local list loaded with", #targetNames, "names")
        return false
    end
end

local function reloadBrainrotNames()
    print("🔄 Reloading name list...")
    return loadBrainrotNames()
end

local function isTargetPrompt(prompt)
    if not prompt then return false end
    
    local objectText = prompt.ObjectText or ""
    if objectText == "" then return false end
    
    for _, targetName in pairs(targetNames) do
        if objectText:find(targetName) then
            return true, targetName
        end
    end
    
    local objectTextLower = objectText:lower()
    for _, targetName in pairs(targetNames) do
        local targetNameLower = targetName:lower()
        if objectTextLower:find(targetNameLower) then
            return true, targetName
        end
    end
    
    return false, nil
end

local function activateProximityPrompt(prompt)
    if not prompt or not prompt.Parent then return end
    
    local promptId = tostring(prompt)
    local currentTime = tick()
    
    if lastActivation[promptId] and currentTime - lastActivation[promptId] < 2 then
        return
    end
    
    lastActivation[promptId] = currentTime
    
    spawn(function()
        print("🔄 Trying to activate ProximityPrompt - ObjectText:", prompt.ObjectText or "N/A")
        
        local success1 = pcall(function()
            if fireproximityprompt then
                fireproximityprompt(prompt)
                print("✅ Activated via fireproximityprompt")
                return true
            end
        end)
        
        if success1 then return end
        
        local success2 = pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            wait(prompt.HoldDuration > 0 and prompt.HoldDuration + 0.1 or 0.1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            print("✅ Activated via VirtualInputManager (key E)")
            return true
        end)
        
        if success2 then return end
        
        local success3 = pcall(function()
            if prompt.HoldDuration > 0 then
                prompt:InputHoldBegin()
                wait(prompt.HoldDuration + 0.1)
                prompt:InputHoldEnd()
                print("✅ Activated via InputHold (duration:", prompt.HoldDuration, ")")
            else
                prompt:InputHoldBegin()
                wait(ACTIVATION_DELAY)
                prompt:InputHoldEnd()
                print("✅ Activated via quick InputHold")
            end
            return true
        end)
        
        if success3 then return end
        
        local success4 = pcall(function()
            prompt.Triggered:Fire(player)
            print("✅ Activated via Triggered:Fire")
            return true
        end)
        
        if success4 then return end
        
        local success5 = pcall(function()
            local connection
            connection = UserInputService.InputBegan:Connect(function(input)
                if input.KeyCode == Enum.KeyCode.E then
                    connection:Disconnect()
                end
            end)
            
            game:GetService("VirtualUser"):TypeKey("e")
            wait(0.1)
            
            connection:Disconnect()
            print("✅ Activated via VirtualUser")
            return true
        end)
        
        if not success5 then
            print("❌ Failed to activate ProximityPrompt - ObjectText:", prompt.ObjectText or "N/A")
        end
    end)
end

local function monitorProximityPrompts()
    connections[#connections + 1] = ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
        print("👁️ ProximityPrompt shown:", prompt.Parent.Name)
        print("🔍 ObjectText found:", prompt.ObjectText or "N/A")
        
        local isTarget, foundName = isTargetPrompt(prompt)
        
        if isTarget then
            print("✅ Target prompt detected! Name found:", foundName)
            print("📝 Full ObjectText:", prompt.ObjectText)
            
            if AUTO_ACTIVATE then
                wait(0.2)
                activateProximityPrompt(prompt)
            else
                print("⚠️ Auto-activation is disabled")
            end
        else
            print("❌ Not a target prompt - ObjectText:", prompt.ObjectText or "N/A")
        end
    end)
    
    connections[#connections + 1] = ProximityPromptService.PromptHidden:Connect(function(prompt, inputType)
        local promptId = tostring(prompt)
        if trackedPrompts[promptId] then
            trackedPrompts[promptId] = nil
            print("👋 Hidden proximity prompt - ObjectText:", prompt.ObjectText or "N/A")
        end
    end)
end

local function scanExistingPrompts()
    if not character or not humanoidRootPart then
        character = player.Character
        if not character then return end
        humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
    end
    
    local playerPosition = humanoidRootPart.Position
    local promptsFound = 0
    
    for _, obj in pairs(game.Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local isTarget, foundName = isTargetPrompt(obj)
            
            if isTarget then
                local promptParent = obj.Parent
                local modelPosition = nil
                
                if promptParent:IsA("BasePart") then
                    modelPosition = promptParent.Position
                elseif promptParent:FindFirstChild("HumanoidRootPart") then
                    modelPosition = promptParent.HumanoidRootPart.Position
                elseif promptParent:IsA("Model") and promptParent.PrimaryPart then
                    modelPosition = promptParent.PrimaryPart.Position
                else
                    local currentParent = promptParent.Parent
                    while currentParent and currentParent ~= game.Workspace do
                        if currentParent:IsA("BasePart") then
                            modelPosition = currentParent.Position
                            break
                        elseif currentParent:FindFirstChild("HumanoidRootPart") then
                            modelPosition = currentParent.HumanoidRootPart.Position
                            break
                        elseif currentParent:IsA("Model") and currentParent.PrimaryPart then
                            modelPosition = currentParent.PrimaryPart.Position
                            break
                        end
                        
                        for _, child in pairs(currentParent:GetDescendants()) do
                            if child:IsA("BasePart") then
                                modelPosition = child.Position
                                break
                            end
                        end
                        
                        if modelPosition then break end
                        currentParent = currentParent.Parent
                    end
                end
                
                if modelPosition then
                    local distance = (playerPosition - modelPosition).Magnitude
                    
                    if distance <= MAX_DISTANCE then
                        promptsFound = promptsFound + 1
                        print("🎯 Target prompt found at", math.floor(distance), "studs:", foundName, "- ObjectText:", obj.ObjectText)
                        
                        if AUTO_ACTIVATE then
                            activateProximityPrompt(obj)
                        end
                    end
                else
                    print("⚠️ Unable to calculate distance for:", foundName)
                    if AUTO_ACTIVATE then
                        promptsFound = promptsFound + 1
                        print("🎯 Trying to enable prompt without checking distance:", foundName)
                        activateProximityPrompt(obj)
                    end
                end
            end
        end
    end
    
    if promptsFound > 0 then
        print("📊 Total Target Prompts Found:", promptsFound)
    end
end

local function onCharacterAdded(newCharacter)
    character = newCharacter
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    trackedPrompts = {}
    lastActivation = {}
    print("🔄 New character uploaded")
end

local function cleanup()
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
    connections = {}
    print("🧹 Clean connections")
end

-- Conectar eventos
connections[#connections + 1] = player.CharacterAdded:Connect(onCharacterAdded)

-- Comandos de chat
connections[#connections + 1] = player.Chatted:Connect(function(message)
    local msg = message:lower()
    if msg == "/debug" then
        print("=== 🐛 DEBUG INFO ===")
        print("Character:", character and character.Name or "nil")
        print("HumanoidRootPart:", humanoidRootPart and "OK" or "nil")
        print("Auto activate:", AUTO_ACTIVATE)
        print("Max distance:", MAX_DISTANCE)
        print("Loaded names:", #targetNames)
        
        print("📋 Target name list:")
        for i, name in pairs(targetNames) do
            print("  " .. i .. ". " .. name)
        end
        
        local totalPrompts = 0
        local targetPrompts = 0
        
        for _, obj in pairs(game.Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                totalPrompts = totalPrompts + 1
                
                local isTarget, foundName = isTargetPrompt(obj)
                if isTarget then
                    targetPrompts = targetPrompts + 1
                    print("🎯 Target prompt found:", foundName, "| ObjectText:", obj.ObjectText, "| Enabled:", obj.Enabled, "| MaxDistance:", obj.MaxActivationDistance)
                end
            end
        end
        
        print("📊 Total ProximityPrompts:", totalPrompts)
        print("🎯 Target prompts found:", targetPrompts)
        print("🔗 Active connections:", #connections)
        
    elseif msg == "/reload" then
        print("🔄 Reloading name list...")
        local success = reloadBrainrotNames()
        if success then
            print("✅ List reloaded successfully!")
        else
            print("⚠️ Using local list as fallback")
        end
        
    elseif msg == "/names" then
        print("=== 📋 BRAINROT NAME LIST ===")
        print("Total names:", #targetNames)
        for i, name in pairs(targetNames) do
            print("  " .. i .. ". " .. name)
        end
        
    elseif msg == "/toggle" then
        AUTO_ACTIVATE = not AUTO_ACTIVATE
        print("🔄 Auto activate:", AUTO_ACTIVATE and "ON ✅" or "OFF ❌")
        
    elseif msg == "/scan" then
        print("🔍 Performing manual scan...")
        scanExistingPrompts()
        
    elseif msg == "/distance" then
        print("📏 Current distance:", MAX_DISTANCE)
        
    elseif msg:match("/distance (%d+)") then
        local newDistance = tonumber(msg:match("/distance (%d+)"))
        if newDistance and newDistance > 0 then
            MAX_DISTANCE = newDistance
            print("📏 New distance set:", MAX_DISTANCE)
        else
            print("❌ Invalid distance! Use a number greater than 0")
        end
        
    elseif msg == "/cleanup" then
        cleanup()
        print("🧹 Manual cleanup executed")
        
    elseif msg == "/testprompt" then
        print("🧪 Testing specific prompt detection...")
        local found = 0
        for _, obj in pairs(game.Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.ObjectText then
                local isTarget, foundName = isTargetPrompt(obj)
                if isTarget then
                    found = found + 1
                    print("🎯 PROMPT FOUND:")
                    print("   ObjectText:", obj.ObjectText)
                    print("   Parent:", obj.Parent.Name)
                    print("   Enabled:", obj.Enabled)
                    print("   MaxActivationDistance:", obj.MaxActivationDistance)
                    print("   Detected name:", foundName)
                    print("   ---")
                end
            end
        end
        if found == 0 then
            print("❌ No target prompts found")
        else
            print("📊 Total target prompts:", found)
        end
        
    elseif msg == "/help" then
        print("=== 📚 AVAILABLE COMMANDS ===")
        print("/debug - Debug information")
        print("/reload - Reload name list from GitHub")
        print("/names - Show target name list")
        print("/toggle - Turn auto activation on/off")
        print("/scan - Manual scan")
        print("/testprompt - Test prompt detection")
        print("/distance [number] - Set maximum distance")
        print("/distance - Show current distance")
        print("/cleanup - Clean up connections")
        print("/help - Show this help")
    end
    end)

-- Cleanup quando o jogador deixa o jogo (apenas para LocalScript)
connections[#connections + 1] = game.Players.PlayerRemoving:Connect(function(leavingPlayer)
    if leavingPlayer == player then
        cleanup()
    end
end)

print("=== 🚀 Auto Activator by ObjectText V5 Starting ===")

local loadSuccess = loadBrainrotNames()

monitorProximityPrompts()

local lastScan = 0
connections[#connections + 1] = RunService.Heartbeat:Connect(function()
    local currentTime = tick()
    if currentTime - lastScan >= 1 then
        lastScan = currentTime
        pcall(scanExistingPrompts)
    end
end)

print("=== ✅ Auto Activator by ObjectText V5 Started ===")
print("🎯 Total names loaded:", #targetNames)
print("📚 Type /help to see available commands")
print("🔄 Auto activate:", AUTO_ACTIVATE and "ON ✅" or "OFF ❌")
print("📏 Maximum distance:", MAX_DISTANCE)
if loadSuccess then
    print("🌐 List loaded from GitHub ✅")
else
    print("📋 Using local list as fallback ⚠️")
end

spawn(function()
    wait(2)
    print("🎯 Performing initial scan...")
    scanExistingPrompts()
end)
