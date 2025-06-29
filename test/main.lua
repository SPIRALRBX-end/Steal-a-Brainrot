-- Script para ativar automaticamente ProximityPrompts dos modelos Brainrot
-- Versão 6 - OTIMIZADA - Redução significativa de lag
-- Coloque este script no StarterGui como LocalScript

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Configurações
local AUTO_ACTIVATE = true
local MAX_DISTANCE = 15
local ACTIVATION_DELAY = 0.1

-- URL da lista de nomes
local BRAINROT_NAMES_URL = "https://raw.githubusercontent.com/SPIRALRBX-end/steal/refs/heads/main/brainrot_names.lua"

-- Tabelas de controle otimizadas
local trackedPrompts = {}
local lastActivation = {}
local connections = {}
local targetNames = {}
local processedPrompts = {} -- Cache para evitar reprocessamento
local scanQueue = {} -- Fila para processamento assíncrono

-- Cache otimizado para verificação de nomes
local targetNamesCache = {}

-- Função para carregar lista de nomes via HTTP
local function loadBrainrotNames()
    print("🌐 Carregando lista de nomes Brainrot...")
    
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
        -- Criar cache otimizado em minúsculas
        targetNamesCache = {}
        for i, name in pairs(targetNames) do
            targetNamesCache[i] = {
                original = name,
                lower = name:lower()
            }
        end
        
        print("✅ Lista carregada com sucesso! Total de nomes:", #targetNames)
        return true
    else
        -- Fallback para lista local
        print("⚠️ Falha ao carregar lista online, usando lista local...")
        targetNames = {
            "Lirili Larila",
            "Lirilì Larilà", 
            "Noobini Pizzanini",
            "Tim Cheese",
            "La Vacca Saturno Saturnita",
            "Los Tralaleritos", 
            "Graipuss Medussi",
            "La Grande Combinasion",
            "Matteo",
            "Trenostruzzo Turbo 3000",
            "Odin Din Din Dun",
            "Gattatino Nyanino"
        }
        
        -- Criar cache para fallback
        targetNamesCache = {}
        for i, name in pairs(targetNames) do
            targetNamesCache[i] = {
                original = name,
                lower = name:lower()
            }
        end
        
        print("📋 Lista local carregada com", #targetNames, "nomes")
        return false
    end
end

-- Função otimizada para verificar se o ProximityPrompt é de um modelo específico
local function isTargetPrompt(prompt)
    if not prompt or not prompt.ObjectText then return false end
    
    local objectText = prompt.ObjectText
    if objectText == "" then return false end
    
    local objectTextLower = objectText:lower()
    
    -- Usar cache otimizado
    for _, nameData in pairs(targetNamesCache) do
        if objectText:find(nameData.original) or objectTextLower:find(nameData.lower) then
            return true, nameData.original
        end
    end
    
    return false, nil
end

-- Função otimizada para ativar um ProximityPrompt
local function activateProximityPrompt(prompt)
    if not prompt or not prompt.Parent then return end
    
    local promptId = tostring(prompt)
    local currentTime = tick()
    
    -- Evitar spam com cooldown menor
    if lastActivation[promptId] and currentTime - lastActivation[promptId] < 1 then
        return
    end
    
    lastActivation[promptId] = currentTime
    
    -- Usar coroutine ao invés de spawn para melhor performance
    coroutine.wrap(function()
        print("🔄 Ativando:", prompt.ObjectText or "N/A")
        
        -- Método mais eficiente - fireproximityprompt primeiro
        local success = pcall(function()
            if fireproximityprompt then
                fireproximityprompt(prompt)
                print("✅ Ativado via fireproximityprompt")
                return
            end
        end)
        
        if success then return end
        
        -- Método 2: InputHold otimizado
        pcall(function()
            if prompt.HoldDuration > 0 then
                prompt:InputHoldBegin()
                wait(math.min(prompt.HoldDuration + 0.05, 0.5)) -- Limite máximo
                prompt:InputHoldEnd()
            else
                prompt:InputHoldBegin()
                wait(ACTIVATION_DELAY)
                prompt:InputHoldEnd()
            end
            print("✅ Ativado via InputHold")
        end)
    end)()
end

-- Sistema de cache para posições
local positionCache = {}
local cacheUpdateTime = 0

local function getModelPosition(promptParent)
    local cacheKey = tostring(promptParent)
    local currentTime = tick()
    
    -- Usar cache se disponível e recente (0.5s)
    if positionCache[cacheKey] and currentTime - positionCache[cacheKey].time < 0.5 then
        return positionCache[cacheKey].position
    end
    
    local position = nil
    
    -- Otimizar busca de posição
    if promptParent:IsA("BasePart") then
        position = promptParent.Position
    elseif promptParent:FindFirstChild("HumanoidRootPart") then
        position = promptParent.HumanoidRootPart.Position
    elseif promptParent:IsA("Model") and promptParent.PrimaryPart then
        position = promptParent.PrimaryPart.Position
    else
        -- Busca limitada para evitar lag
        for i, child in pairs(promptParent:GetChildren()) do
            if i > 10 then break end -- Limitar busca
            if child:IsA("BasePart") then
                position = child.Position
                break
            end
        end
    end
    
    -- Atualizar cache
    if position then
        positionCache[cacheKey] = {
            position = position,
            time = currentTime
        }
    end
    
    return position
end

-- Função para processar prompts em lotes (evitar travamentos)
local function processPromptsQueue()
    local processed = 0
    local maxPerFrame = 5 -- Processar máximo 5 por frame
    
    while #scanQueue > 0 and processed < maxPerFrame do
        local prompt = table.remove(scanQueue, 1)
        processed = processed + 1
        
        if prompt and prompt.Parent then
            local promptId = tostring(prompt)
            
            -- Evitar reprocessar o mesmo prompt recentemente
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
                        print("🎯 Prompt encontrado:", foundName, "- Distância:", math.floor(distance))
                        
                        if AUTO_ACTIVATE then
                            activateProximityPrompt(prompt)
                        end
                    end
                end
            end
        end
    end
end

-- Função otimizada para scan (não bloqueia o jogo)
local function scanExistingPrompts()
    if not character or not humanoidRootPart then
        character = player.Character
        if not character then return end
        humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
    end
    
    -- Limitar área de scan para melhor performance
    local playerPosition = humanoidRootPart.Position
    local scanRegion = Region3.new(
        playerPosition - Vector3.new(MAX_DISTANCE * 2, MAX_DISTANCE * 2, MAX_DISTANCE * 2),
        playerPosition + Vector3.new(MAX_DISTANCE * 2, MAX_DISTANCE * 2, MAX_DISTANCE * 2)
    )
    
    -- Usar ReadVoxels para scan mais eficiente (se disponível)
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

-- Monitor otimizado de ProximityPrompts
local function monitorProximityPrompts()
    connections[#connections + 1] = ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
        local isTarget, foundName = isTargetPrompt(prompt)
        
        if isTarget then
            print("✅ Prompt alvo detectado:", foundName)
            
            if AUTO_ACTIVATE then
                -- Delay menor para resposta mais rápida
                wait(0.1)
                activateProximityPrompt(prompt)
            end
        end
    end)
    
    connections[#connections + 1] = ProximityPromptService.PromptHidden:Connect(function(prompt, inputType)
        local promptId = tostring(prompt)
        trackedPrompts[promptId] = nil
        processedPrompts[promptId] = nil -- Limpar cache
    end)
end

-- Função para lidar com novo character
local function onCharacterAdded(newCharacter)
    character = newCharacter
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    -- Limpar caches
    trackedPrompts = {}
    lastActivation = {}
    processedPrompts = {}
    positionCache = {}
    scanQueue = {}
    
    print("🔄 Novo character carregado - caches limpos")
end

-- Função para limpar conexões e caches
local function cleanup()
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
    connections = {}
    
    -- Limpar todos os caches
    trackedPrompts = {}
    lastActivation = {}
    processedPrompts = {}
    positionCache = {}
    scanQueue = {}
    
    print("🧹 Cleanup completo realizado")
end

-- Limpar cache periodicamente para evitar memory leak
local function cleanupCache()
    local currentTime = tick()
    
    -- Limpar lastActivation antigos
    for promptId, time in pairs(lastActivation) do
        if currentTime - time > 30 then -- 30 segundos
            lastActivation[promptId] = nil
        end
    end
    
    -- Limpar processedPrompts antigos
    for promptId, time in pairs(processedPrompts) do
        if currentTime - time > 10 then -- 10 segundos
            processedPrompts[promptId] = nil
        end
    end
    
    -- Limpar positionCache antigo
    for key, data in pairs(positionCache) do
        if currentTime - data.time > 2 then -- 2 segundos
            positionCache[key] = nil
        end
    end
end

-- Conectar eventos
connections[#connections + 1] = player.CharacterAdded:Connect(onCharacterAdded)

-- Comandos de chat (simplificados para melhor performance)
connections[#connections + 1] = player.Chatted:Connect(function(message)
    local msg = message:lower()
    
    if msg == "/debug" then
        print("=== 🐛 DEBUG INFO OTIMIZADO ===")
        print("Character:", character and "OK" or "nil")
        print("Auto activate:", AUTO_ACTIVATE)
        print("Nomes carregados:", #targetNames)
        print("Queue size:", #scanQueue)
        print("Cache sizes - Position:", #positionCache, "Processed:", #processedPrompts)
        
    elseif msg == "/toggle" then
        AUTO_ACTIVATE = not AUTO_ACTIVATE
        print("🔄 Auto activate:", AUTO_ACTIVATE and "LIGADO ✅" or "DESLIGADO ❌")
        
    elseif msg == "/scan" then
        print("🔍 Scan manual iniciado...")
        scanQueue = {} -- Limpar queue
        scanExistingPrompts()
        
    elseif msg == "/cleanup" then
        cleanup()
        
    elseif msg == "/cache" then
        print("📊 Cache info:")
        print("Position cache:", #positionCache)
        print("Processed cache:", #processedPrompts)
        print("Scan queue:", #scanQueue)
        
    elseif msg == "/help" then
        print("=== 📚 COMANDOS OTIMIZADOS ===")
        print("/debug - Info de debug")
        print("/toggle - Toggle auto ativação")
        print("/scan - Scan manual")
        print("/cache - Info do cache")
        print("/cleanup - Limpar tudo")
        print("/help - Esta ajuda")
    end
end)

-- Cleanup quando sair
connections[#connections + 1] = game.Players.PlayerRemoving:Connect(function(leavingPlayer)
    if leavingPlayer == player then
        cleanup()
    end
end)

-- Inicialização
print("=== 🚀 Auto Activator OTIMIZADO V6 Iniciando ===")

loadBrainrotNames()
monitorProximityPrompts()

-- Loop principal otimizado
local lastScan = 0
local lastCleanup = 0

connections[#connections + 1] = RunService.Heartbeat:Connect(function()
    local currentTime = tick()
    
    -- Processar queue a cada frame (sem lag)
    if #scanQueue > 0 then
        processPromptsQueue()
    end
    
    -- Scan a cada 3 segundos (reduzido de 1 segundo)
    if currentTime - lastScan >= 3 then
        lastScan = currentTime
        if #scanQueue < 50 then -- Só fazer scan se queue não estiver cheia
            pcall(scanExistingPrompts)
        end
    end
    
    -- Cleanup de cache a cada 15 segundos
    if currentTime - lastCleanup >= 15 then
        lastCleanup = currentTime
        cleanupCache()
    end
end)

print("=== ✅ Auto Activator OTIMIZADO V6 Iniciado ===")
print("🎯 Nomes carregados:", #targetNames)
print("⚡ Otimizações ativas: Cache, Queue, Scan limitado")
print("📚 Digite /help para comandos")

-- Scan inicial após 2 segundos
coroutine.wrap(function()
    wait(2)
    print("🎯 Scan inicial...")
    scanExistingPrompts()
end)()