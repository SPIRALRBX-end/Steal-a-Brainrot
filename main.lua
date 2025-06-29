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

local BRAINROT_NAMES_URL = "https://raw.githubusercontent.com/SPIRALRBX-end/steal/refs/heads/main/brainrot_names.lua"

local trackedPrompts = {}
local lastActivation = {}
local connections = {}
local targetNames = {}
local processedPrompts = {}
local scanQueue = {}

local targetNamesCache = {}

local function loadBrainrotNames()
    local success, result = pcall(function()
        local loadstring_func = loadstring or load
        if loadstring_func then
            local code = game:HttpGet(BRAINROT_NAMES_URL)
            local namesList = loadstring_func(code)()
            return namesList
        else
            error("Loadstring não disponível")
        end
    end)
    
    if success and result and type(result) == "table" then
        targetNames = result
        targetNamesCache = {}
        for i, name in pairs(targetNames) do
            targetNamesCache[i] = {
                original = name,
                lower = name:lower()
            }
        end
        return true
    else
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
        
        targetNamesCache = {}
        for i, name in pairs(targetNames) do
            targetNamesCache[i] = {
                original = name,
                lower = name:lower()
            }
        end
        return false
    end
end

local function isTargetPrompt(prompt)
    if not prompt or not prompt.ObjectText then return false end
    
    local objectText = prompt.ObjectText
    if objectText == "" then return false end
    
    local objectTextLower = objectText:lower()
    
    for _, nameData in pairs(targetNamesCache) do
        if objectText:find(nameData.original) or objectTextLower:find(nameData.lower) then
            return true, nameData.original
        end
    end
    
    return false, nil
end

local function activateProximityPrompt(prompt)
    if not prompt or not prompt.Parent then return end
    
    local promptId = tostring(prompt)
    local currentTime = tick()
    
    if lastActivation[promptId] and currentTime - lastActivation[promptId] < 1 then
        return
    end
    
    lastActivation[promptId] = currentTime
    
    coroutine.wrap(function()
        local success = pcall(function()
            if fireproximityprompt then
                fireproximityprompt(prompt)
                return
            end
        end)
        
        if success then return end
        
        pcall(function()
            if prompt.HoldDuration > 0 then
                prompt:InputHoldBegin()
                wait(math.min(prompt.HoldDuration + 0.05, 0.5))
                prompt:InputHoldEnd()
            else
                prompt:InputHoldBegin()
                wait(ACTIVATION_DELAY)
                prompt:InputHoldEnd()
            end
        end)
    end)()
end

local positionCache = {}
local cacheUpdateTime = 0

local function getModelPosition(promptParent)
    local cacheKey = tostring(promptParent)
    local currentTime = tick()
    
    if positionCache[cacheKey] and currentTime - positionCache[cacheKey].time < 0.5 then
        return positionCache[cacheKey].position
    end
    
    local position = nil
    
    if promptParent:IsA("BasePart") then
        position = promptParent.Position
    elseif promptParent:FindFirstChild("HumanoidRootPart") then
        position = promptParent.HumanoidRootPart.Position
    elseif promptParent:IsA("Model") and promptParent.PrimaryPart then
        position = promptParent.PrimaryPart.Position
    else
        for i, child in pairs(promptParent:GetChildren()) do
            if i > 10 then break end
            if child:IsA("BasePart") then
                position = child.Position
                break
            end
        end
    end
    
    if position then
        positionCache[cacheKey] = {
            position = position,
            time = currentTime
        }
    end
    
    return position
end

local function processPromptsQueue()
    local processed = 0
    local maxPerFrame = 5
    
    while #scanQueue > 0 and processed < maxPerFrame do
        local prompt = table.remove(scanQueue, 1)
        processed = processed + 1
        
        if prompt and prompt.Parent then
            local promptId = tostring(prompt)
            
            if processedPrompts[promptId] and tick() - processedPrompts[promptId] < 2 then
                continue
            end
            
            processedPrompts[promptId] = tick()
            
            local isTarget, foundName = isTargetPrompt(prompt)
            
            if isTarget and character and humanoidRootPart then
                local playerPosition = humanoidRootPart.Position
                local modelPosition = getModelPosition(prompt.Parent)
                
                if modelPosition then
                    local distance = (playerPosition - modelPosition).Magnitude
                    
                    if distance <= MAX_DISTANCE then
                        if AUTO_ACTIVATE then
                            activateProximityPrompt(prompt)
                        end
                    end
                end
            end
        end
    end
end

local function scanExistingPrompts()
    if not character or not humanoidRootPart then
        character = player.Character
        if not character then return end
        humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
    end
    
    local playerPosition = humanoidRootPart.Position
    local scanRegion = Region3.new(
        playerPosition - Vector3.new(MAX_DISTANCE * 2, MAX_DISTANCE * 2, MAX_DISTANCE * 2),
        playerPosition + Vector3.new(MAX_DISTANCE * 2, MAX_DISTANCE * 2, MAX_DISTANCE * 2)
    )
    
    pcall(function()
        local parts = game.Workspace:ReadVoxels(scanRegion, 4)
        for _, part in pairs(parts) do
            for _, descendant in pairs(part:GetChildren()) do
                if descendant:IsA("ProximityPrompt") and descendant.Enabled then
                    table.insert(scanQueue, descendant)
                end
            end
        end
    end)
end

local function monitorProximityPrompts()
    connections[#connections + 1] = ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
        local isTarget, foundName = isTargetPrompt(prompt)
        
        if isTarget then
            if AUTO_ACTIVATE then
                wait(0.1)
                activateProximityPrompt(prompt)
            end
        end
    end)
    
    connections[#connections + 1] = ProximityPromptService.PromptHidden:Connect(function(prompt, inputType)
        local promptId = tostring(prompt)
        trackedPrompts[promptId] = nil
        processedPrompts[promptId] = nil
    end)
end

local function onCharacterAdded(newCharacter)
    character = newCharacter
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    trackedPrompts = {}
    lastActivation = {}
    processedPrompts = {}
    positionCache = {}
    scanQueue = {}
end

local function cleanup()
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
    connections = {}
    
    trackedPrompts = {}
    lastActivation = {}
    processedPrompts = {}
    positionCache = {}
    scanQueue = {}
end

local function cleanupCache()
    local currentTime = tick()
    
    for promptId, time in pairs(lastActivation) do
        if currentTime - time > 30 then
            lastActivation[promptId] = nil
        end
    end
    
    for promptId, time in pairs(processedPrompts) do
        if currentTime - time > 10 then
            processedPrompts[promptId] = nil
        end
    end
    
    for key, data in pairs(positionCache) do
        if currentTime - data.time > 2 then
            positionCache[key] = nil
        end
    end
end

connections[#connections + 1] = player.CharacterAdded:Connect(onCharacterAdded)

connections[#connections + 1] = player.Chatted:Connect(function(message)
    local msg = message:lower()
    
    if msg == "/debug" then
        print("=== DEBUG INFO ===")
        print("Character:", character and "OK" or "nil")
        print("Auto activate:", AUTO_ACTIVATE)
        print("Nomes carregados:", #targetNames)
        print("Queue size:", #scanQueue)
        print("Cache sizes - Position:", #positionCache, "Processed:", #processedPrompts)
        
    elseif msg == "/toggle" then
        AUTO_ACTIVATE = not AUTO_ACTIVATE
        print("Auto activate:", AUTO_ACTIVATE and "LIGADO" or "DESLIGADO")
        
    elseif msg == "/scan" then
        print("Scan manual iniciado...")
        scanQueue = {}
        scanExistingPrompts()
        
    elseif msg == "/cleanup" then
        cleanup()
        
    elseif msg == "/cache" then
        print("Cache info:")
        print("Position cache:", #positionCache)
        print("Processed cache:", #processedPrompts)
        print("Scan queue:", #scanQueue)
        
    elseif msg == "/help" then
        print("=== COMANDOS ===")
        print("/debug - Info de debug")
        print("/toggle - Toggle auto ativação")
        print("/scan - Scan manual")
        print("/cache - Info do cache")
        print("/cleanup - Limpar tudo")
        print("/help - Esta ajuda")
    end
end)

connections[#connections + 1] = game.Players.PlayerRemoving:Connect(function(leavingPlayer)
    if leavingPlayer == player then
        cleanup()
    end
end)

print("=== Auto Activator V6 Iniciando ===")

loadBrainrotNames()
monitorProximityPrompts()

local lastScan = 0
local lastCleanup = 0

connections[#connections + 1] = RunService.Heartbeat:Connect(function()
    local currentTime = tick()
    
    if #scanQueue > 0 then
        processPromptsQueue()
    end
    
    if currentTime - lastScan >= 3 then
        lastScan = currentTime
        if #scanQueue < 50 then
            pcall(scanExistingPrompts)
        end
    end
    
    if currentTime - lastCleanup >= 15 then
        lastCleanup = currentTime
        cleanupCache()
    end
end)

print("=== Auto Activator V6 Iniciado ===")
print("Nomes carregados:", #targetNames)
print("Otimizações ativas: Cache, Queue, Scan limitado")
print("Digite /help para comandos")

coroutine.wrap(function()
    wait(2)
    print("Scan inicial...")
    scanExistingPrompts()
end)()
