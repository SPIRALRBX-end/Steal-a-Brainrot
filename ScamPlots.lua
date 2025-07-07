-- Serviços
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Variáveis de controle
local isMoving = false
local currentConnection = nil

-- Função para obter o idioma do usuário (simplificado)
local function getLocalizedText(key)
    local texts = {
        ["en"] = {
            title = "Base Animal Scanner",
            selectBase = "Select Base",
            emptyBase = "Empty Base",
            noAnimals = "No Animals Found",
            animals = "Animals",
            close = "Close",
            refresh = "Refresh"
        },
        ["pt"] = {
            title = "Scanner de Animais da Base",
            selectBase = "Selecionar Base",
            emptyBase = "Base Vazia",
            noAnimals = "Nenhum Animal Encontrado",
            animals = "Animais",
            close = "Fechar",
            refresh = "Atualizar"
        }
    }
    
    local locale = game:GetService("LocalizationService").RobloxLocaleId
    local lang = string.sub(locale, 1, 2)
    
    return texts[lang] and texts[lang][key] or texts["en"][key]
end

-- Função para normalizar nomes (substituir - por _)
local function normalizeName(name)
    return string.gsub(name, "%-", "_")
end

-- Função para encontrar a base do player
local function findPlayerBase()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    
    for _, plot in pairs(plots:GetChildren()) do
        if plot:IsA("Model") then
            local plotSign = plot:FindFirstChild("PlotSign")
            if plotSign then
                local surfaceGui = plotSign:FindFirstChild("SurfaceGui")
                if surfaceGui then
                    local frame = surfaceGui:FindFirstChild("Frame")
                    if frame then
                        local textLabel = frame:FindFirstChild("TextLabel")
                        if textLabel and textLabel.Text == player.Name then
                            return plot
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- Função para mover o player suavemente
local function moveToPosition(targetPosition, callback)
    if isMoving then return end
    
    isMoving = true
    local startPosition = rootPart.Position
    local distance = (targetPosition - startPosition).Magnitude
    local speed = 50 -- Velocidade em studs por segundo
    local duration = distance / speed
    
    local tweenInfo = TweenInfo.new(
        duration,
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.InOut
    )
    
    local tween = TweenService:Create(rootPart, tweenInfo, {Position = targetPosition})
    
    tween:Play()
    tween.Completed:Connect(function()
        isMoving = false
        if callback then
            callback()
        end
    end)
end

-- Função para verificar se a base está desbloqueada
local function isBaseUnlocked(plotModel)
    local purchases = plotModel:FindFirstChild("Purchases")
    if not purchases then return true end
    
    local plotBlock = purchases:FindFirstChild("PlotBlock")
    if not plotBlock then return true end
    
    local main = plotBlock:FindFirstChild("Main")
    if not main then return true end
    
    local billboardGui = main:FindFirstChild("BillboardGui")
    if not billboardGui then return true end
    
    local remainingTime = billboardGui:FindFirstChild("RemainingTime")
    if not remainingTime then return true end
    
    return remainingTime.Text == "0"
end

-- Função para ir até um animal específico
local function goToAnimal(plotModel, slotNumber)
    if isMoving then return end
    
    local animalPodiums = plotModel:FindFirstChild("AnimalPodiums")
    if not animalPodiums then return end
    
    local podium = animalPodiums:FindFirstChild(tostring(slotNumber))
    if not podium then return end
    
    local base = podium:FindFirstChild("Base")
    if not base then return end
    
    local spawn = base:FindFirstChild("Spawn")
    if not spawn then return end
    
    -- Posição acima da base (para voar)
    local targetPosition = plotModel.PrimaryPart.Position + Vector3.new(0, 50, 0)
    
    -- Primeiro, voar até acima da base
    moveToPosition(targetPosition, function()
        -- Verificar se a base está desbloqueada
        if isBaseUnlocked(plotModel) then
            -- Descer até o animal
            local animalPosition = spawn.Position + Vector3.new(0, 5, 0)
            moveToPosition(animalPosition, function()
                -- Ativar o ProximityPrompt
                local promptAttachment = spawn:FindFirstChild("PromptAttachment")
                if promptAttachment then
                    local proximityPrompt = promptAttachment:FindFirstChild("ProximityPrompt")
                    if proximityPrompt then
                        proximityPrompt:InputHoldBegan()
                        wait(0.1)
                        proximityPrompt:InputHoldEnded()
                    end
                end
                
                -- Voltar para cima
                moveToPosition(targetPosition, function()
                    -- Voltar para a base do player
                    local playerBase = findPlayerBase()
                    if playerBase then
                        local playerBasePosition = playerBase.PrimaryPart.Position + Vector3.new(0, 50, 0)
                        moveToPosition(playerBasePosition, function()
                            -- Descer até o multiplier da base do player
                            local multiplier = playerBase:FindFirstChild("Multiplier")
                            if multiplier then
                                local multiplierPosition = multiplier.Position + Vector3.new(0, 5, 0)
                                moveToPosition(multiplierPosition, nil)
                            end
                        end)
                    end
                end)
            end)
        else
            -- Se a base estiver bloqueada, apenas voltar
            local playerBase = findPlayerBase()
            if playerBase then
                local playerBasePosition = playerBase.PrimaryPart.Position + Vector3.new(0, 50, 0)
                moveToPosition(playerBasePosition, nil)
            end
        end
    end)
end

-- Função para criar a interface
local function createInterface()
    -- Screen GUI principal
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BaseAnimalScanner"
    screenGui.Parent = playerGui
    screenGui.ResetOnSpawn = false
    
    -- Frame principal
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 600, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    -- Cantos arredondados
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = mainFrame
    
    -- Título
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, 0, 0, 50)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    titleLabel.Text = getLocalizedText("title")
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 18
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleLabel
    
    -- Botão fechar
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0, 10)
    closeButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 14
    closeButton.Font = Enum.Font.SourceSansBold
    closeButton.Parent = mainFrame
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 5)
    closeCorner.Parent = closeButton
    
    -- Frame de seleção de base
    local baseFrame = Instance.new("Frame")
    baseFrame.Name = "BaseFrame"
    baseFrame.Size = UDim2.new(0.48, 0, 0.8, 0)
    baseFrame.Position = UDim2.new(0.02, 0, 0.15, 0)
    baseFrame.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    baseFrame.BorderSizePixel = 0
    baseFrame.Parent = mainFrame
    
    local baseCorner = Instance.new("UICorner")
    baseCorner.CornerRadius = UDim.new(0, 8)
    baseCorner.Parent = baseFrame
    
    -- Título da seção de bases
    local baseTitle = Instance.new("TextLabel")
    baseTitle.Name = "BaseTitle"
    baseTitle.Size = UDim2.new(1, 0, 0, 30)
    baseTitle.Position = UDim2.new(0, 0, 0, 0)
    baseTitle.BackgroundTransparency = 1
    baseTitle.Text = getLocalizedText("selectBase")
    baseTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    baseTitle.TextSize = 14
    baseTitle.Font = Enum.Font.SourceSansBold
    baseTitle.Parent = baseFrame
    
    -- ScrollingFrame para bases
    local baseScrollFrame = Instance.new("ScrollingFrame")
    baseScrollFrame.Name = "BaseScrollFrame"
    baseScrollFrame.Size = UDim2.new(1, -10, 1, -40)
    baseScrollFrame.Position = UDim2.new(0, 5, 0, 35)
    baseScrollFrame.BackgroundTransparency = 1
    baseScrollFrame.BorderSizePixel = 0
    baseScrollFrame.ScrollBarThickness = 4
    baseScrollFrame.Parent = baseFrame
    
    -- Layout para bases
    local baseLayout = Instance.new("UIListLayout")
    baseLayout.SortOrder = Enum.SortOrder.LayoutOrder
    baseLayout.Padding = UDim.new(0, 5)
    baseLayout.Parent = baseScrollFrame
    
    -- Frame de animais
    local animalFrame = Instance.new("Frame")
    animalFrame.Name = "AnimalFrame"
    animalFrame.Size = UDim2.new(0.48, 0, 0.8, 0)
    animalFrame.Position = UDim2.new(0.5, 0, 0.15, 0)
    animalFrame.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    animalFrame.BorderSizePixel = 0
    animalFrame.Parent = mainFrame
    
    local animalCorner = Instance.new("UICorner")
    animalCorner.CornerRadius = UDim.new(0, 8)
    animalCorner.Parent = animalFrame
    
    -- Título da seção de animais
    local animalTitle = Instance.new("TextLabel")
    animalTitle.Name = "AnimalTitle"
    animalTitle.Size = UDim2.new(1, 0, 0, 30)
    animalTitle.Position = UDim2.new(0, 0, 0, 0)
    animalTitle.BackgroundTransparency = 1
    animalTitle.Text = getLocalizedText("animals")
    animalTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    animalTitle.TextSize = 14
    animalTitle.Font = Enum.Font.SourceSansBold
    animalTitle.Parent = animalFrame
    
    -- ScrollingFrame para animais
    local animalScrollFrame = Instance.new("ScrollingFrame")
    animalScrollFrame.Name = "AnimalScrollFrame"
    animalScrollFrame.Size = UDim2.new(1, -10, 1, -40)
    animalScrollFrame.Position = UDim2.new(0, 5, 0, 35)
    animalScrollFrame.BackgroundTransparency = 1
    animalScrollFrame.BorderSizePixel = 0
    animalScrollFrame.ScrollBarThickness = 4
    animalScrollFrame.Parent = animalFrame
    
    -- Layout para animais
    local animalLayout = Instance.new("UIListLayout")
    animalLayout.SortOrder = Enum.SortOrder.LayoutOrder
    animalLayout.Padding = UDim.new(0, 5)
    animalLayout.Parent = animalScrollFrame
    
    -- Botão refresh
    local refreshButton = Instance.new("TextButton")
    refreshButton.Name = "RefreshButton"
    refreshButton.Size = UDim2.new(0, 100, 0, 30)
    refreshButton.Position = UDim2.new(0.5, -50, 1, -40)
    refreshButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    refreshButton.Text = getLocalizedText("refresh")
    refreshButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    refreshButton.TextSize = 12
    refreshButton.Font = Enum.Font.SourceSans
    refreshButton.Parent = mainFrame
    
    local refreshCorner = Instance.new("UICorner")
    refreshCorner.CornerRadius = UDim.new(0, 5)
    refreshCorner.Parent = refreshButton
    
    return screenGui, baseScrollFrame, animalScrollFrame, closeButton, refreshButton
end

-- Função para obter informações das bases
local function getBasesInfo()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then
        return {}
    end
    
    local basesInfo = {}
    
    for _, plot in pairs(plots:GetChildren()) do
        if plot:IsA("Model") then
            local plotSign = plot:FindFirstChild("PlotSign")
            if plotSign then
                local surfaceGui = plotSign:FindFirstChild("SurfaceGui")
                if surfaceGui then
                    local frame = surfaceGui:FindFirstChild("Frame")
                    if frame then
                        local textLabel = frame:FindFirstChild("TextLabel")
                        if textLabel then
                            local baseName = textLabel.Text
                            if baseName and baseName ~= "" then
                                table.insert(basesInfo, {
                                    plotId = plot.Name,
                                    baseName = baseName,
                                    plotModel = plot
                                })
                            end
                        end
                    end
                end
            end
        end
    end
    
    return basesInfo
end

-- Função para obter animais de uma base
local function getAnimalsFromBase(plotModel)
    local animals = {}
    local animalPodiums = plotModel:FindFirstChild("AnimalPodiums")
    
    if animalPodiums then
        for _, podium in pairs(animalPodiums:GetChildren()) do
            if podium:IsA("Model") and tonumber(podium.Name) then
                local base = podium:FindFirstChild("Base")
                if base then
                    local spawn = base:FindFirstChild("Spawn")
                    if spawn then
                        local attachment = spawn:FindFirstChild("Attachment")
                        if attachment then
                            local animalOverhead = attachment:FindFirstChild("AnimalOverhead")
                            if animalOverhead then
                                local displayName = animalOverhead:FindFirstChild("DisplayName")
                                if displayName then
                                    local animalName = displayName.Text
                                    if animalName and animalName ~= "" then
                                        table.insert(animals, {
                                            slot = podium.Name,
                                            name = animalName,
                                            plotModel = plotModel
                                        })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return animals
end

-- Função para criar botão de base
local function createBaseButton(parent, baseInfo, onClickCallback)
    local normalizedId = normalizeName(baseInfo.plotId)
    
    local button = Instance.new("TextButton")
    button.Name = "BaseButton_" .. normalizedId
    button.Size = UDim2.new(1, 0, 0, 35)
    button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    button.Text = baseInfo.baseName
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 12
    button.Font = Enum.Font.SourceSans
    button.TextTruncate = Enum.TextTruncate.AtEnd
    button.Parent = parent
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 5)
    buttonCorner.Parent = button
    
    -- Efeito hover
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    end)
    
    button.MouseButton1Click:Connect(function()
        onClickCallback(baseInfo)
    end)
    
    return button
end

-- Função para criar botão de animal
local function createAnimalButton(parent, animalInfo)
    local button = Instance.new("TextButton")
    button.Name = "AnimalButton_" .. animalInfo.slot
    button.Size = UDim2.new(1, 0, 0, 35)
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.BorderSizePixel = 0
    button.Parent = parent
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 5)
    buttonCorner.Parent = button
    
    -- Frame interno para organizar o conteúdo
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, 0, 1, 0)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = button
    
    -- Slot number
    local slotLabel = Instance.new("TextLabel")
    slotLabel.Name = "SlotLabel"
    slotLabel.Size = UDim2.new(0, 30, 1, 0)
    slotLabel.Position = UDim2.new(0, 0, 0, 0)
    slotLabel.BackgroundTransparency = 1
    slotLabel.Text = animalInfo.slot
    slotLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    slotLabel.TextSize = 10
    slotLabel.Font = Enum.Font.SourceSans
    slotLabel.Parent = contentFrame
    
    -- Animal name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, -35, 1, 0)
    nameLabel.Position = UDim2.new(0, 35, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = animalInfo.name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 11
    nameLabel.Font = Enum.Font.SourceSans
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = contentFrame
    
    -- Efeito hover
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end)
    
    -- Evento de clique
    button.MouseButton1Click:Connect(function()
        goToAnimal(animalInfo.plotModel, animalInfo.slot)
    end)
    
    return button
end

-- Função principal
local function main()
    local screenGui, baseScrollFrame, animalScrollFrame, closeButton, refreshButton = createInterface()
    
    -- Função para limpar frames
    local function clearFrames()
        for _, child in pairs(baseScrollFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        for _, child in pairs(animalScrollFrame:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("TextLabel") then
                child:Destroy()
            end
        end
    end
    
    -- Função para mostrar animais
    local function showAnimals(baseInfo)
        -- Limpar animais anteriores
        for _, child in pairs(animalScrollFrame:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("TextLabel") then
                child:Destroy()
            end
        end
        
        local animals = getAnimalsFromBase(baseInfo.plotModel)
        
        if #animals == 0 then
            local noAnimalsLabel = Instance.new("TextLabel")
            noAnimalsLabel.Name = "NoAnimalsLabel"
            noAnimalsLabel.Size = UDim2.new(1, 0, 0, 30)
            noAnimalsLabel.BackgroundTransparency = 1
            noAnimalsLabel.Text = getLocalizedText("noAnimals")
            noAnimalsLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            noAnimalsLabel.TextSize = 12
            noAnimalsLabel.Font = Enum.Font.SourceSans
            noAnimalsLabel.Parent = animalScrollFrame
        else
            for _, animalInfo in pairs(animals) do
                createAnimalButton(animalScrollFrame, animalInfo)
            end
        end
        
        -- Atualizar tamanho do canvas
        animalScrollFrame.CanvasSize = UDim2.new(0, 0, 0, animalScrollFrame.UIListLayout.AbsoluteContentSize.Y)
    end
    
    -- Função para carregar bases
    local function loadBases()
        clearFrames()
        
        local basesInfo = getBasesInfo()
        
        if #basesInfo == 0 then
            local emptyLabel = Instance.new("TextLabel")
            emptyLabel.Name = "EmptyLabel"
            emptyLabel.Size = UDim2.new(1, 0, 0, 35)
            emptyLabel.BackgroundTransparency = 1
            emptyLabel.Text = getLocalizedText("emptyBase")
            emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            emptyLabel.TextSize = 12
            emptyLabel.Font = Enum.Font.SourceSans
            emptyLabel.Parent = baseScrollFrame
        else
            for _, baseInfo in pairs(basesInfo) do
                createBaseButton(baseScrollFrame, baseInfo, showAnimals)
            end
        end
        
        -- Atualizar tamanho do canvas
        baseScrollFrame.CanvasSize = UDim2.new(0, 0, 0, baseScrollFrame.UIListLayout.AbsoluteContentSize.Y)
    end
    
    -- Eventos
    closeButton.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    refreshButton.MouseButton1Click:Connect(function()
        loadBases()
    end)
    
    -- Carregar bases inicialmente
    loadBases()
    
    -- Tornar a interface arrastável
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    local function updateInput(input)
        local delta = input.Position - dragStart
        local position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        screenGui.MainFrame.Position = position
    end
    
    screenGui.MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = screenGui.MainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    screenGui.MainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            if dragging then
                updateInput(input)
            end
        end
    end)
end

-- Atualizar referências do character quando o player respawna
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
end)

-- Executar o script
main()