-- Script para ativar automaticamente ProximityPrompts dos modelos Brainrot
-- Versão 3 - CORRIGIDA
-- Coloque este script no StarterGui como LocalScript

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Configurações
local AUTO_ACTIVATE = true
local MAX_DISTANCE = 15
local ACTIVATION_DELAY = 0.1

-- Tabelas de controle
local trackedPrompts = {}
local lastActivation = {}
local connections = {}

-- Função para verificar se é um modelo Brainrot/La Vacca
local function isBrainrotModel(model)
    if not model then return false end
    
    -- MODO DEBUG: Ativar TODOS os ProximityPrompts para teste
    -- Remova este return true depois de confirmar que funciona
    return true
    
    -- Código original (descomente quando quiser filtrar apenas modelos específicos)
    --[[
    if not model.Name then return false end
    
    local name = model.Name:lower()
    return name:match("lirilì") or 
           name:match("larilà") or 
           name:match("lirili") or 
           name:match("larila") or
           name == "lirilì larilà" or
           name:match("brainrot") or
           name:match("vacca") or
           name:match("saturno") or
           name:match("saturnita")
    --]]
end

-- Função melhorada para ativar ProximityPrompt
local function activateProximityPrompt(prompt)
    if not prompt or not prompt.Parent then return end
    
    local promptId = tostring(prompt)
    local currentTime = tick()
    
    -- Evitar spam
    if lastActivation[promptId] and currentTime - lastActivation[promptId] < 2 then
        return
    end
    
    lastActivation[promptId] = currentTime
    
    spawn(function()
        print("🔄 Tentando ativar ProximityPrompt:", prompt.Parent.Name)
        
        -- Método 1: fireproximityprompt (exploit function)
        local success1 = pcall(function()
            if fireproximityprompt then
                fireproximityprompt(prompt)
                print("✅ Ativado via fireproximityprompt")
                return true
            end
        end)
        
        if success1 then return end
        
        -- Método 2: Simular input via VirtualInputManager
        local success2 = pcall(function()
            -- Simular pressionamento da tecla E
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            wait(prompt.HoldDuration > 0 and prompt.HoldDuration + 0.1 or 0.1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            print("✅ Ativado via VirtualInputManager (tecla E)")
            return true
        end)
        
        if success2 then return end
        
        -- Método 3: InputHold methods
        local success3 = pcall(function()
            if prompt.HoldDuration > 0 then
                prompt:InputHoldBegin()
                wait(prompt.HoldDuration + 0.1)
                prompt:InputHoldEnd()
                print("✅ Ativado via InputHold (duração:", prompt.HoldDuration, ")")
            else
                prompt:InputHoldBegin()
                wait(ACTIVATION_DELAY)
                prompt:InputHoldEnd()
                print("✅ Ativado via InputHold rápido")
            end
            return true
        end)
        
        if success3 then return end
        
        -- Método 4: Forçar trigger do prompt
        local success4 = pcall(function()
            prompt.Triggered:Fire(player)
            print("✅ Ativado via Triggered:Fire")
            return true
        end)
        
        if success4 then return end
        
        -- Método 5: UserInputService
        local success5 = pcall(function()
            local connection
            connection = UserInputService.InputBegan:Connect(function(input)
                if input.KeyCode == Enum.KeyCode.E then
                    connection:Disconnect()
                end
            end)
            
            UserInputService:GetService("UserInputService"):SimulateKeyDown(Enum.KeyCode.E)
            wait(0.1)
            UserInputService:GetService("UserInputService"):SimulateKeyUp(Enum.KeyCode.E)
            
            connection:Disconnect()
            print("✅ Ativado via UserInputService")
            return true
        end)
        
        if not success5 then
            print("❌ Falha ao ativar ProximityPrompt:", prompt.Parent.Name)
        end
    end)
end

-- Função para monitorar ProximityPrompts criados dinamicamente
local function monitorProximityPrompts()
    -- Conectar ao evento de ProximityPrompt triggered
    connections[#connections + 1] = ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
        print("👁️ ProximityPrompt mostrado:", prompt.Parent.Name)
        
        -- Verificar se é de um modelo Brainrot
        local model = prompt.Parent
        local modelPath = ""
        
        -- Encontrar o modelo pai e mostrar o caminho completo
        local currentObj = model
        local pathParts = {}
        
        while currentObj and currentObj ~= game.Workspace do
            table.insert(pathParts, 1, currentObj.Name)
            if currentObj:IsA("Model") then
                model = currentObj
                break
            end
            currentObj = currentObj.Parent
        end
        
        modelPath = table.concat(pathParts, " -> ")
        
        print("📍 Caminho completo:", modelPath)
        print("🏷️ Nome do modelo:", model and model.Name or "N/A")
        print("🔍 Verificando se é Brainrot...")
        
        if model and isBrainrotModel(model) then
            print("✅ Brainrot ProximityPrompt detectado! Modelo:", model.Name)
            if AUTO_ACTIVATE then
                -- Aguardar um pouco para garantir que o prompt está totalmente carregado
                wait(0.2)
                activateProximityPrompt(prompt)
            else
                print("⚠️ Auto activate está desligado")
            end
        else
            print("❌ Não é um modelo Brainrot:", model and model.Name or "N/A")
        end
    end)
    
    connections[#connections + 1] = ProximityPromptService.PromptHidden:Connect(function(prompt, inputType)
        local promptId = tostring(prompt)
        if trackedPrompts[promptId] then
            trackedPrompts[promptId] = nil
            print("👋 ProximityPrompt escondido:", prompt.Parent.Name)
        end
    end)
end

-- Função alternativa que escaneia todos os ProximityPrompts existentes
local function scanExistingPrompts()
    if not character or not humanoidRootPart then
        character = player.Character
        if not character then return end
        humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
    end
    
    local playerPosition = humanoidRootPart.Position
    local promptsFound = 0
    
    -- Escanear workspace
    for _, obj in pairs(game.Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local model = obj.Parent
            local searchDepth = 0
            
            -- Procurar pelo modelo pai (máximo 10 níveis)
            while model and not model:IsA("Model") and searchDepth < 10 do
                model = model.Parent
                searchDepth = searchDepth + 1
            end
            
            if model and isBrainrotModel(model) then
                -- Calcular distância
                local modelPosition = nil
                
                -- Tentar encontrar uma part para calcular distância
                if model:FindFirstChild("HumanoidRootPart") then
                    modelPosition = model.HumanoidRootPart.Position
                elseif model.PrimaryPart then
                    modelPosition = model.PrimaryPart.Position
                else
                    -- Usar a primeira part encontrada
                    for _, child in pairs(model:GetDescendants()) do
                        if child:IsA("BasePart") then
                            modelPosition = child.Position
                            break
                        end
                    end
                end
                
                if modelPosition then
                    local distance = (playerPosition - modelPosition).Magnitude
                    
                    if distance <= MAX_DISTANCE then
                        promptsFound = promptsFound + 1
                        print("🎯 ProximityPrompt encontrado a", math.floor(distance), "studs:", model.Name)
                        
                        if AUTO_ACTIVATE then
                            activateProximityPrompt(obj)
                        end
                    end
                end
            end
        end
    end
    
    if promptsFound > 0 then
        print("📊 Total de prompts encontrados:", promptsFound)
    end
end

-- Função para lidar com novo character
local function onCharacterAdded(newCharacter)
    character = newCharacter
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    trackedPrompts = {}
    lastActivation = {}
    print("🔄 Novo character carregado")
end

-- Função para limpar conexões
local function cleanup()
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
    connections = {}
    print("🧹 Conexões limpas")
end

-- Conectar eventos
connections[#connections + 1] = player.CharacterAdded:Connect(onCharacterAdded)

-- Monitorar ProximityPrompts
monitorProximityPrompts()

-- Loop principal para scan alternativo (reduzir frequência para melhor performance)
local lastScan = 0
connections[#connections + 1] = RunService.Heartbeat:Connect(function()
    local currentTime = tick()
    if currentTime - lastScan >= 1 then -- Scan a cada 1 segundo
        lastScan = currentTime
        pcall(scanExistingPrompts)
    end
end)

-- Comandos de chat
connections[#connections + 1] = player.Chatted:Connect(function(message)
    local msg = message:lower()
    if msg == "/debug" then
        print("=== 🐛 DEBUG INFO ===")
        print("Character:", character and character.Name or "nil")
        print("HumanoidRootPart:", humanoidRootPart and "OK" or "nil")
        print("Auto activate:", AUTO_ACTIVATE)
        print("Max distance:", MAX_DISTANCE)
        
        -- Contar ProximityPrompts no workspace
        local totalPrompts = 0
        local brainrotPrompts = 0
        
        for _, obj in pairs(game.Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                totalPrompts = totalPrompts + 1
                
                local model = obj.Parent
                local searchDepth = 0
                while model and not model:IsA("Model") and searchDepth < 10 do
                    model = model.Parent
                    searchDepth = searchDepth + 1
                end
                
                if model and isBrainrotModel(model) then
                    brainrotPrompts = brainrotPrompts + 1
                    print("🎯 Brainrot prompt encontrado:", model.Name, "| Habilitado:", obj.Enabled, "| MaxDistance:", obj.MaxActivationDistance)
                end
            end
        end
        
        print("📊 Total ProximityPrompts:", totalPrompts)
        print("🎯 Brainrot ProximityPrompts:", brainrotPrompts)
        print("🔗 Conexões ativas:", #connections)
        
    elseif msg == "/toggle" then
        AUTO_ACTIVATE = not AUTO_ACTIVATE
        print("🔄 Auto activate:", AUTO_ACTIVATE and "LIGADO ✅" or "DESLIGADO ❌")
        
    elseif msg == "/scan" then
        print("🔍 Executando scan manual...")
        scanExistingPrompts()
        
    elseif msg == "/distance" then
        print("📏 Distância atual:", MAX_DISTANCE)
        
    elseif msg:match("/distance (%d+)") then
        local newDistance = tonumber(msg:match("/distance (%d+)"))
        if newDistance and newDistance > 0 then
            MAX_DISTANCE = newDistance
            print("📏 Nova distância definida:", MAX_DISTANCE)
        else
            print("❌ Distância inválida! Use um número maior que 0")
        end
        
    elseif msg == "/cleanup" then
        cleanup()
        print("🧹 Limpeza manual executada")
        
    elseif msg == "/help" then
        print("=== 📚 COMANDOS DISPONÍVEIS ===")
        print("/debug - Informações de debug")
        print("/toggle - Ligar/desligar auto ativação")
        print("/scan - Scan manual")
        print("/distance [número] - Definir distância máxima")
        print("/distance - Ver distância atual")
        print("/cleanup - Limpar conexões")
        print("/help - Mostrar esta ajuda")
    end
end)

-- Cleanup quando o jogador deixa o jogo (apenas para LocalScript)
connections[#connections + 1] = game.Players.PlayerRemoving:Connect(function(leavingPlayer)
    if leavingPlayer == player then
        cleanup()
    end
end)

print("=== 🚀 Auto Brainrot Activator V3 Iniciado ===")
print("🔍 Monitorando ProximityPrompts reais do Roblox...")
print("📚 Digite /help para ver comandos disponíveis")
print("🔄 Auto activate:", AUTO_ACTIVATE and "LIGADO ✅" or "DESLIGADO ❌")
print("📏 Distância máxima:", MAX_DISTANCE)

-- Scan inicial após 2 segundos
spawn(function()
    wait(2)
    print("🎯 Executando scan inicial...")
    scanExistingPrompts()
end)
