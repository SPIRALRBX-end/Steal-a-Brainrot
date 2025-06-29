-- Script para ativar automaticamente ProximityPrompts dos modelos Brainrot
-- Versão que intercepta ProximityPrompts reais do Roblox
-- Coloque este script no StarterGui como LocalScript

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

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

-- Função para verificar se é um modelo Brainrot/La Vacca
local function isBrainrotModel(model)
    if not model then return false end
    
    -- MODO DEBUG: Ativar TODOS os ProximityPrompts para teste
    -- Remova este return true depois de confirmar que funciona
    return true
    
    -- Código original (comentado para debug)
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

-- Função para ativar um ProximityPrompt
local function activateProximityPrompt(prompt)
    if not prompt or not prompt.Parent then return end
    
    local promptId = tostring(prompt)
    local currentTime = tick()
    
    -- Evitar spam
    if lastActivation[promptId] and currentTime - lastActivation[promptId] < 1 then
        return
    end
    
    lastActivation[promptId] = currentTime
    
    spawn(function()
        print("Ativando ProximityPrompt:", prompt.Parent.Name)
        
        -- Método 1: Usar fireproximityprompt (se disponível)
        pcall(function()
            if fireproximityprompt then
                fireproximityprompt(prompt)
                print("Ativado via fireproximityprompt")
                return
            end
        end)
        
        -- Método 2: Simular input manual
        pcall(function()
            if prompt.HoldDuration > 0 then
                prompt:InputHoldBegin()
                wait(prompt.HoldDuration + 0.1)
                prompt:InputHoldEnd()
                print("Ativado via InputHold (duração:", prompt.HoldDuration, ")")
            else
                prompt:InputHoldBegin()
                wait(ACTIVATION_DELAY)
                prompt:InputHoldEnd()
                print("Ativado via InputHold rápido")
            end
        end)
        
        -- Método 3: Tentar ativar via eventos
        pcall(function()
            -- Procurar por BindableEvents relacionados
            for _, child in pairs(prompt:GetChildren()) do
                if child:IsA("BindableEvent") then
                    child:Fire()
                    print("Ativado via BindableEvent:", child.Name)
                end
            end
        end)
        
        -- Método 4: Simular tecla E
        pcall(function()
            UserInputService:SimulateKeyDown(Enum.KeyCode.E)
            wait(0.1)
            UserInputService:SimulateKeyUp(Enum.KeyCode.E)
            print("Simulou tecla E")
        end)
    end)
end

-- Função para monitorar ProximityPrompts criados dinamicamente
local function monitorProximityPrompts()
    -- Conectar ao evento de ProximityPrompt triggered
    ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
        print("ProximityPrompt mostrado:", prompt.Parent.Name)
        
        -- Verificar se é de um modelo Brainrot
        local model = prompt.Parent
        local modelPath = ""
        
        -- Encontrar o modelo pai e mostrar o caminho completo
        while model and not model:IsA("Model") do
            modelPath = model.Name .. " -> " .. modelPath
            model = model.Parent
        end
        
        if model then
            modelPath = model.Name .. " -> " .. modelPath
            print("Caminho completo:", modelPath)
            print("Nome do modelo:", model.Name)
            print("Verificando se é Brainrot...")
            
            if isBrainrotModel(model) then
                print("✅ Brainrot ProximityPrompt detectado! Modelo:", model.Name)
                if AUTO_ACTIVATE then
                    wait(0.1)
                    activateProximityPrompt(prompt)
                else
                    print("⚠️ Auto activate está desligado")
                end
            else
                print("❌ Não é um modelo Brainrot:", model.Name)
            end
        else
            print("❌ Não foi possível encontrar o modelo pai")
        end
    end)
    
    ProximityPromptService.PromptHidden:Connect(function(prompt, inputType)
        local promptId = tostring(prompt)
        if trackedPrompts[promptId] then
            trackedPrompts[promptId] = nil
            print("ProximityPrompt escondido:", prompt.Parent.Name)
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
            while model and not model:IsA("Model") do
                model = model.Parent
            end
            
            if model and isBrainrotModel(model) then
                -- Calcular distância
                local modelPosition = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
                if modelPosition then
                    local distance = (playerPosition - modelPosition.Position).Magnitude
                    
                    if distance <= MAX_DISTANCE then
                        promptsFound = promptsFound + 1
                        print("ProximityPrompt encontrado a", math.floor(distance), "studs:", model.Name)
                        
                        if AUTO_ACTIVATE then
                            activateProximityPrompt(obj)
                        end
                    end
                end
            end
        end
    end
    
    if promptsFound > 0 then
        print("Total de prompts encontrados:", promptsFound)
    end
end

-- Função para lidar com novo character
local function onCharacterAdded(newCharacter)
    character = newCharacter
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    trackedPrompts = {}
    lastActivation = {}
    print("Novo character carregado")
end

-- Conectar eventos
player.CharacterAdded:Connect(onCharacterAdded)

-- Monitorar ProximityPrompts
monitorProximityPrompts()

-- Loop principal para scan alternativo
local heartbeatConnection = RunService.Heartbeat:Connect(function()
    pcall(scanExistingPrompts)
end)

-- Comandos de chat
player.Chatted:Connect(function(message)
    local msg = message:lower()
    if msg == "/debug" then
        print("=== DEBUG INFO ===")
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
                while model and not model:IsA("Model") do
                    model = model.Parent
                end
                
                if model and isBrainrotModel(model) then
                    brainrotPrompts = brainrotPrompts + 1
                    print("Brainrot prompt encontrado:", model.Name, "| Habilitado:", obj.Enabled)
                end
            end
        end
        
        print("Total ProximityPrompts:", totalPrompts)
        print("Brainrot ProximityPrompts:", brainrotPrompts)
        
    elseif msg == "/toggle" then
        AUTO_ACTIVATE = not AUTO_ACTIVATE
        print("Auto activate:", AUTO_ACTIVATE and "LIGADO" or "DESLIGADO")
        
    elseif msg == "/scan" then
        print("Executando scan manual...")
        scanExistingPrompts()
        
    elseif msg == "/distance" then
        print("Distância atual:", MAX_DISTANCE)
        
    elseif msg:match("/distance (%d+)") then
        local newDistance = tonumber(msg:match("/distance (%d+)"))
        if newDistance then
            MAX_DISTANCE = newDistance
            print("Nova distância definida:", MAX_DISTANCE)
        end
    end
end)

-- Limpeza
game:BindToClose(function()
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
    end
end)

print("=== Auto Brainrot Activator V2 Iniciado ===")
print("Monitorando ProximityPrompts reais do Roblox...")
print("Comandos disponíveis:")
print("/debug - Informações de debug")
print("/toggle - Ligar/desligar auto ativação")
print("/scan - Scan manual")
print("/distance [número] - Definir distância máxima")
print("/distance - Ver distância atual")
print("Auto activate:", AUTO_ACTIVATE and "LIGADO" or "DESLIGADO")

-- Scan inicial
wait(2)
scanExistingPrompts()
