-- Script para ativar automaticamente ProximityPrompts dos modelos Brainrot
-- Versão 4 - CORRIGIDA (Função isBrainrotModel removida e lógica melhorada)
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

-- Função para verificar se o ProximityPrompt é de um modelo específico
local function isTargetPrompt(prompt)
    if not prompt then return false end
    
    -- Verificar ObjectText do ProximityPrompt
    local objectText = prompt.ObjectText or ""
    if objectText == "" then return false end
    
    -- Lista dos nomes específicos que queremos ativar
    local targetNames = {
        "Lirili Larila",
        "Lirilì Larilà", 
        "Noobini Pizzanini",
        "Tim Cheese"
    }
    
    -- Verificar se o ObjectText contém algum dos nomes alvos
    for _, targetName in pairs(targetNames) do
        if objectText:find(targetName) then
            return true, targetName
        end
    end
    
    -- Verificar versões em minúsculas e sem acentos
    local objectTextLower = objectText:lower()
    local alternativeNames = {
        "lirili larila",
        "lirilì larilà",
        "noobini pizzanini", 
        "tim cheese"
    }
    
    for i, altName in pairs(alternativeNames) do
        if objectTextLower:find(altName) then
            return true, targetNames[i] or altName
        end
    end
    
    return false, nil
end

-- Função para ativar um ProximityPrompt
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
        print("🔄 Tentando ativar ProximityPrompt - ObjectText:", prompt.ObjectText or "N/A")
        
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
            
            -- Simular tecla E
            game:GetService("VirtualUser"):TypeKey("e")
            wait(0.1)
            
            connection:Disconnect()
            print("✅ Ativado via VirtualUser")
            return true
        end)
        
        if not success5 then
            print("❌ Falha ao ativar ProximityPrompt - ObjectText:", prompt.ObjectText or "N/A")
        end
    end)
end

-- Função para monitorar ProximityPrompts criados dinamicamente
local function monitorProximityPrompts()
    -- Conectar ao evento de ProximityPrompt triggered
    connections[#connections + 1] = ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
        print("👁️ ProximityPrompt mostrado:", prompt.Parent.Name)
        print("🔍 ObjectText encontrado:", prompt.ObjectText or "N/A")
        
        -- Verificar se é um prompt alvo pelo ObjectText
        local isTarget, foundName = isTargetPrompt(prompt)
        
        if isTarget then
            print("✅ Prompt alvo detectado! Nome encontrado:", foundName)
            print("📝 ObjectText completo:", prompt.ObjectText)
            
            if AUTO_ACTIVATE then
                -- Aguardar um pouco para garantir que o prompt está totalmente carregado
                wait(0.2)
                activateProximityPrompt(prompt)
            else
                print("⚠️ Auto activate está desligado")
            end
        else
            print("❌ Não é um prompt alvo - ObjectText:", prompt.ObjectText or "N/A")
        end
    end)
    
    connections[#connections + 1] = ProximityPromptService.PromptHidden:Connect(function(prompt, inputType)
        local promptId = tostring(prompt)
        if trackedPrompts[promptId] then
            trackedPrompts[promptId] = nil
            print("👋 ProximityPrompt escondido - ObjectText:", prompt.ObjectText or "N/A")
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
            -- Verificar se é um prompt alvo pelo ObjectText
            local isTarget, foundName = isTargetPrompt(obj)
            
            if isTarget then
                -- Calcular distância usando o parent do prompt
                local promptParent = obj.Parent
                local modelPosition = nil
                
                -- Tentar encontrar uma part para calcular distância
                if promptParent:IsA("BasePart") then
                    modelPosition = promptParent.Position
                elseif promptParent:FindFirstChild("HumanoidRootPart") then
                    modelPosition = promptParent.HumanoidRootPart.Position
                elseif promptParent:IsA("Model") and promptParent.PrimaryPart then
                    modelPosition = promptParent.PrimaryPart.Position
                else
                    -- Buscar qualquer BasePart no parent ou parents acima
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
                        
                        -- Buscar qualquer BasePart no currentParent
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
                        print("🎯 Prompt alvo encontrado a", math.floor(distance), "studs:", foundName, "- ObjectText:", obj.ObjectText)
                        
                        if AUTO_ACTIVATE then
                            activateProximityPrompt(obj)
                        end
                    end
                else
                    print("⚠️ Não foi possível calcular distância para:", foundName)
                    -- Tentar ativar mesmo assim se estiver muito próximo
                    if AUTO_ACTIVATE then
                        promptsFound = promptsFound + 1
                        print("🎯 Tentando ativar prompt sem verificar distância:", foundName)
                        activateProximityPrompt(obj)
                    end
                end
            end
        end
    end
    
    if promptsFound > 0 then
        print("📊 Total de prompts alvos encontrados:", promptsFound)
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
        local targetPrompts = 0
        
        for _, obj in pairs(game.Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                totalPrompts = totalPrompts + 1
                
                local isTarget, foundName = isTargetPrompt(obj)
                if isTarget then
                    targetPrompts = targetPrompts + 1
                    print("🎯 Prompt alvo encontrado:", foundName, "| ObjectText:", obj.ObjectText, "| Habilitado:", obj.Enabled, "| MaxDistance:", obj.MaxActivationDistance)
                end
            end
        end
        
        print("📊 Total ProximityPrompts:", totalPrompts)
        print("🎯 Prompts alvos encontrados:", targetPrompts)
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
        
    elseif msg == "/list" then
        print("=== 📋 LISTA DE PROMPTS PRÓXIMOS ===")
        if not character or not humanoidRootPart then
            print("❌ Character ou HumanoidRootPart não encontrado")
            return
        end
        
        local playerPosition = humanoidRootPart.Position
        local promptsFound = 0
        
        for _, obj in pairs(game.Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Enabled then
                -- Calcular distância
                local promptParent = obj.Parent
                local modelPosition = nil
                
                if promptParent:IsA("BasePart") then
                    modelPosition = promptParent.Position
                else
                    for _, child in pairs(promptParent:GetDescendants()) do
                        if child:IsA("BasePart") then
                            modelPosition = child.Position
                            break
                        end
                    end
                end
                
                if modelPosition then
                    local distance = (playerPosition - modelPosition).Magnitude
                    
                    if distance <= MAX_DISTANCE * 2 then -- Usar distância maior para listagem
                        promptsFound = promptsFound + 1
                        local isTarget, foundName = isTargetPrompt(obj)
                        local status = isTarget and "✅ ALVO" or "❌ IGNORADO"
                        
                        print(string.format("%d. %s | Distância: %d studs", promptsFound, status, math.floor(distance)))
                        print("   ObjectText: '" .. (obj.ObjectText or "N/A") .. "'")
                        print("   Parent: " .. promptParent.Name)
                        if isTarget then
                            print("   Nome encontrado: " .. foundName)
                        end
                        print("   ---")
                    end
                end
            end
        end
        
        if promptsFound == 0 then
            print("❌ Nenhum ProximityPrompt encontrado na área")
        else
            print("📊 Total encontrado:", promptsFound)
        end
        
    elseif msg == "/testprompt" then
        print("🧪 Testando detecção de prompts específicos...")
        for _, obj in pairs(game.Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.ObjectText then
                local objectText = obj.ObjectText
                if objectText:find("Noobini") or objectText:find("Tim") or objectText:find("Lirili") then
                    print("🎯 PROMPT ENCONTRADO:")
                    print("   ObjectText:", objectText)
                    print("   Parent:", obj.Parent.Name)
                    print("   Enabled:", obj.Enabled)
                    print("   MaxActivationDistance:", obj.MaxActivationDistance)
                    
                    local isTarget, foundName = isTargetPrompt(obj)
                    print("   É alvo?", isTarget and "SIM ✅" or "NÃO ❌")
                    if isTarget then
                        print("   Nome detectado:", foundName)
                    end
                    print("   ---")
                end
            end
        end
        
    elseif msg == "/help" then
        print("=== 📚 COMANDOS DISPONÍVEIS ===")
        print("/debug - Informações de debug")
        print("/toggle - Ligar/desligar auto ativação")
        print("/scan - Scan manual")
        print("/list - Listar todos os prompts próximos")
        print("/testprompt - Testar detecção de prompts")
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

print("=== 🚀 Auto Activator por ObjectText V4 Iniciado ===")
print("🎯 Monitorando ObjectText: Lirili Larila, Noobini Pizzanini, Tim Cheese")
print("📚 Digite /help para ver comandos disponíveis")
print("🔄 Auto activate:", AUTO_ACTIVATE and "LIGADO ✅" or "DESLIGADO ❌")
print("📏 Distância máxima:", MAX_DISTANCE)

-- Scan inicial após 2 segundos
spawn(function()
    wait(2)
    print("🎯 Executando scan inicial...")
    scanExistingPrompts()
end)
