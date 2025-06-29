-- Script para ativar automaticamente ProximityPrompts dos modelos Brainrot
-- Coloque este script no StarterGui como LocalScript
-- Monitora o PlayerGui em vez dos modelos diretamente

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configurações
local AUTO_CLICK_DELAY = 0.1 -- Delay entre cliques automáticos
local HOLD_DURATION = 0.5 -- Duração para segurar botões se necessário

-- Tabelas para controle
local activePrompts = {}
local lastActivation = {}
local connections = {}

-- Função para verificar se é um prompt relacionado ao Brainrot
local function isBrainrotPrompt(promptContainer)
    if not promptContainer then return false end
    
    -- Verifica se está na estrutura esperada do PlayerGui
    local isInProximityPrompts = false
    local parent = promptContainer.Parent
    
    while parent do
        if parent.Name == "ProximityPrompts" and parent.Parent == playerGui then
            isInProximityPrompts = true
            break
        end
        parent = parent.Parent
    end
    
    return isInProximityPrompts
end

-- Função para encontrar o botão clicável
local function findClickableButton(container)
    local buttons = {}
    
    -- Procurar por TextButton
    for _, child in pairs(container:GetDescendants()) do
        if child:IsA("TextButton") or child:IsA("ImageButton") then
            table.insert(buttons, child)
        end
    end
    
    return buttons
end

-- Função para ativar um prompt automaticamente
local function activatePrompt(promptContainer)
    if not promptContainer or not promptContainer.Parent then return end
    
    local promptId = tostring(promptContainer)
    local currentTime = tick()
    
    -- Evitar spam (ativar apenas uma vez por segundo)
    if lastActivation[promptId] and currentTime - lastActivation[promptId] < 1 then
        return
    end
    
    lastActivation[promptId] = currentTime
    
    spawn(function()
        local buttons = findClickableButton(promptContainer)
        
        for _, button in pairs(buttons) do
            if button.Visible and button.Parent then
                print("Ativando Brainrot Prompt:", button:GetFullName())
                
                -- Tentar diferentes métodos de ativação
                pcall(function()
                    -- Método 1: MouseButton1Click
                    if button:IsA("TextButton") or button:IsA("ImageButton") then
                        button.MouseButton1Click:Fire()
                    end
                end)
                
                pcall(function()
                    -- Método 2: Activated
                    if button.Activated then
                        button.Activated:Fire()
                    end
                end)
                
                pcall(function()
                    -- Método 3: Simular input do usuário
                    UserInputService:SimulateKeyHold(Enum.KeyCode.E, AUTO_CLICK_DELAY)
                end)
                
                wait(AUTO_CLICK_DELAY)
            end
        end
    end)
end

-- Função para monitorar novos prompts no PlayerGui
local function monitorProximityPrompts()
    local proximityPromptsFolder = playerGui:FindFirstChild("ProximityPrompts")
    
    if proximityPromptsFolder then
        -- Monitorar prompts já existentes
        for _, prompt in pairs(proximityPromptsFolder:GetChildren()) do
            if prompt.Name == "Prompt" and isBrainrotPrompt(prompt) then
                activatePrompt(prompt)
            end
        end
        
        -- Monitorar novos prompts que são criados
        if not connections["ProximityPrompts"] then
            connections["ProximityPrompts"] = proximityPromptsFolder.ChildAdded:Connect(function(newPrompt)
                wait(0.1) -- Pequeno delay para garantir que o prompt foi totalmente carregado
                
                if newPrompt.Name == "Prompt" and isBrainrotPrompt(newPrompt) then
                    print("Novo Brainrot Prompt detectado!")
                    activatePrompt(newPrompt)
                end
            end)
        end
    end
end

-- Função para monitorar quando a pasta ProximityPrompts é criada
local function monitorPlayerGui()
    -- Verificar se ProximityPrompts já existe
    monitorProximityPrompts()
    
    -- Monitorar quando ProximityPrompts é criada
    if not connections["PlayerGui"] then
        connections["PlayerGui"] = playerGui.ChildAdded:Connect(function(child)
            if child.Name == "ProximityPrompts" then
                print("ProximityPrompts folder criada!")
                wait(0.1)
                monitorProximityPrompts()
            end
        end)
    end
end

-- Função alternativa que monitora mudanças específicas na interface
local function alternativeMonitoring()
    -- Monitora toda mudança no PlayerGui
    for _, child in pairs(playerGui:GetChildren()) do
        if child.Name == "ProximityPrompts" then
            -- Monitora recursivamente todas as mudanças
            local function monitorDescendants(parent)
                for _, descendant in pairs(parent:GetDescendants()) do
                    if (descendant:IsA("TextButton") or descendant:IsA("ImageButton")) and 
                       descendant.Name:find("Button") then
                        
                        -- Monitora quando o botão fica visível
                        if not connections[tostring(descendant)] then
                            connections[tostring(descendant)] = descendant:GetPropertyChangedSignal("Visible"):Connect(function()
                                if descendant.Visible and isBrainrotPrompt(descendant.Parent) then
                                    wait(0.1)
                                    activatePrompt(descendant.Parent)
                                end
                            end)
                        end
                    end
                end
            end
            
            monitorDescendants(child)
            
            -- Também monitora novos descendentes
            child.DescendantAdded:Connect(function(newDescendant)
                if (newDescendant:IsA("TextButton") or newDescendant:IsA("ImageButton")) and 
                   newDescendant.Name:find("Button") then
                    
                    wait(0.1)
                    if newDescendant.Visible and isBrainrotPrompt(newDescendant.Parent) then
                        activatePrompt(newDescendant.Parent)
                    end
                end
            end)
        end
    end
end

-- Loop principal de monitoramento
local function mainLoop()
    pcall(monitorPlayerGui)
    pcall(alternativeMonitoring)
end

-- Executar loop de monitoramento
local heartbeatConnection = RunService.Heartbeat:Connect(function()
    pcall(mainLoop)
end)

-- Comandos de debug via chat
player.Chatted:Connect(function(message)
    local msg = message:lower()
    if msg == "/debug" then
        print("=== DEBUG INFO ===")
        print("PlayerGui:", playerGui and playerGui.Name or "nil")
        
        local proximityPrompts = playerGui:FindFirstChild("ProximityPrompts")
        if proximityPrompts then
            print("ProximityPrompts encontrado!")
            for _, child in pairs(proximityPrompts:GetChildren()) do
                print("- Child:", child.Name, "| Tipo:", child.ClassName)
            end
        else
            print("ProximityPrompts NÃO encontrado")
        end
        
        print("Conexões ativas:", #connections)
        
    elseif msg == "/scan" then
        print("Executando scan manual...")
        mainLoop()
        
    elseif msg == "/clear" then
        print("Limpando conexões...")
        for _, connection in pairs(connections) do
            if connection then
                connection:Disconnect()
            end
        end
        connections = {}
        activePrompts = {}
        lastActivation = {}
    end
end)

-- Limpeza quando o script é removido
game:BindToClose(function()
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
    end
    
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
end)

print("=== Auto Brainrot Activator Iniciado ===")
print("Monitorando PlayerGui para ProximityPrompts...")
print("Comandos disponíveis:")
print("/debug - Mostrar informações de debug")
print("/scan - Executar scan manual")
print("/clear - Limpar todas as conexões")

-- Inicialização
wait(1)
mainLoop()