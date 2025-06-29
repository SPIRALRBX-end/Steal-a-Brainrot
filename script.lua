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
    
    -- Procurar por TextButton e ImageButton em toda a estrutura
    for _, child in pairs(container:GetDescendants()) do
        if child:IsA("TextButton") or child:IsA("ImageButton") then
            table.insert(buttons, child)
            print("Botão encontrado:", child:GetFullName(), "| Visível:", child.Visible, "| Ativo:", child.Active)
        end
    end
    
    -- Também procurar por Frames que podem ser clicáveis
    for _, child in pairs(container:GetDescendants()) do
        if child:IsA("Frame") and (child.Name:find("Button") or child.Name:find("Input")) then
            table.insert(buttons, child)
            print("Frame clicável encontrado:", child:GetFullName(), "| Visível:", child.Visible)
        end
    end
    
    -- Procurar especificamente pelos caminhos mencionados
    -- game:GetService("Players").LocalPlayer.PlayerGui.ProximityPrompts.Prompt.TextButton
    local textButton = container:FindFirstChild("TextButton")
    if textButton then
        print("TextButton direto encontrado!")
        table.insert(buttons, textButton)
    end
    
    -- game:GetService("Players").LocalPlayer.PlayerGui.ProximityPrompts.Prompt.Frame.InputFrame.Frame.ButtonImage
    local frame = container:FindFirstChild("Frame")
    if frame then
        local inputFrame = frame:FindFirstChild("InputFrame")
        if inputFrame then
            local innerFrame = inputFrame:FindFirstChild("Frame")
            if innerFrame then
                local buttonImage = innerFrame:FindFirstChild("ButtonImage")
                if buttonImage then
                    print("ButtonImage encontrado no caminho específico!")
                    table.insert(buttons, buttonImage)
                end
            end
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
    if lastActivation[promptId] and currentTime - lastActivation[promptId] < 0.5 then
        return
    end
    
    lastActivation[promptId] = currentTime
    
    spawn(function()
        print("Tentando ativar prompt:", promptContainer:GetFullName())
        
        -- Procurar por todos os botões possíveis
        local buttons = findClickableButton(promptContainer)
        
        for _, button in pairs(buttons) do
            if button.Visible and button.Parent then
                print("Botão encontrado:", button:GetFullName())
                print("Tipo do botão:", button.ClassName)
                print("Botão visível:", button.Visible)
                print("Botão ativo:", button.Active)
                
                -- Método 1: MouseButton1Down + MouseButton1Up
                pcall(function()
                    if button:IsA("TextButton") or button:IsA("ImageButton") then
                        print("Tentando MouseButton1Down/Up...")
                        button.MouseButton1Down:Fire()
                        wait(0.1)
                        button.MouseButton1Up:Fire()
                    end
                end)
                
                wait(0.1)
                
                -- Método 2: MouseButton1Click
                pcall(function()
                    if button:IsA("TextButton") or button:IsA("ImageButton") then
                        print("Tentando MouseButton1Click...")
                        button.MouseButton1Click:Fire()
                    end
                end)
                
                wait(0.1)
                
                -- Método 3: Activated
                pcall(function()
                    print("Tentando Activated...")
                    button.Activated:Fire()
                end)
                
                wait(0.1)
                
                -- Método 4: GuiService
                pcall(function()
                    local GuiService = game:GetService("GuiService")
                    print("Tentando GuiService...")
                    GuiService.SelectedObject = button
                    wait(0.1)
                    button.Activated:Fire()
                end)
                
                wait(0.1)
                
                -- Método 5: Simular clique via UserInputService
                pcall(function()
                    print("Tentando UserInputService...")
                    UserInputService:SimulateMouseButton(Enum.UserInputType.MouseButton1, true)
                    wait(0.1)
                    UserInputService:SimulateMouseButton(Enum.UserInputType.MouseButton1, false)
                end)
                
                wait(0.1)
                
                -- Método 6: Tentar encontrar RemoteEvents ou BindableEvents
                pcall(function()
                    print("Procurando por RemoteEvents...")
                    for _, child in pairs(button:GetChildren()) do
                        if child:IsA("RemoteEvent") then
                            print("Encontrado RemoteEvent:", child.Name)
                            child:FireServer()
                        elseif child:IsA("BindableEvent") then
                            print("Encontrado BindableEvent:", child.Name)
                            child:Fire()
                        end
                    end
                end)
                
                wait(0.1)
                
                -- Método 7: Procurar por scripts e tentar ativar diretamente
                pcall(function()
                    print("Verificando eventos do botão...")
                    -- Verificar se o botão tem connections
                    local connections = getconnections and getconnections(button.MouseButton1Click)
                    if connections then
                        for _, connection in pairs(connections) do
                            if connection.Function then
                                print("Executando função conectada...")
                                connection.Function()
                            end
                        end
                    end
                end)
                
                print("Tentativas de ativação concluídas para:", button.Name)
            end
        end
        
        -- Tentar ativar via tecla E (método comum para ProximityPrompts)
        pcall(function()
            print("Tentando tecla E...")
            UserInputService:SimulateKeyDown(Enum.KeyCode.E)
            wait(0.1)
            UserInputService:SimulateKeyUp(Enum.KeyCode.E)
        end)
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
