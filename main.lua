local container = script.Parent
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

local brainrotNames = {
	"Noobini Pizzanini",
	"Lirilì Larilà",
	"Tim Cheese",
	"Fluriflura",
	"Svinina Bombardino",
	"Talpa Di Fero",
	"Pipi Kiwi",
	"Trippi Troppi",
	"Tung Tung Tung Sahur",
	"Gangster Footera",
	"Boneca Ambalabu",
	"Ta Ta Ta Ta Sahur",
	"Tric Trac Baraboom",
	"Bandito Bobritto",
	"Cappuccino Assassino",
	"Brr Brr Patapim",
	"Trulimero Trulicina",
	"Bananita Dolphinita",
	"Brri Brri Bicus Dicus Bombicus",
	"Bambini Crostini",
	"Perochello Lemonchello",
	"Burbaloni Loliloli",
	"Chimpanzini Bananini",
	"Ballerina Cappuccina",
	"Chef Crabracadabra",
	"Glorbo Fruttodrillo",
	"Blueberrinni Octopusini",
	"Lionel Cactuseli",
	"Frigo Camelo",
	"Orangutini Ananassini",
	"Bombardiro Crocodilo",
	"Bombombini Gusini",
	"Rhino Toasterino",
	"Cavallo Virtuoso",
	"Cocofanto Elefanto",
	"Tralalero Tralala",
	"Odin Din Din Dun",
	"Girafa Celestre",
	"Gattatino Nyanino",
	"Trenostruzzo Turbo 3000",
	"Matteo",
	"Unclito Samito",
	"La Vacca Saturno Saturnita",
	"Los Tralaleritos",
	"Graipuss Medussi",
	"La Grande Combinasion",
	"Sammyni Spyderini",
	"Garama and Madundung"
}

local availableNames = {}
local selected = {}
local AUTO_ACTIVATE = false
local SCRIPT_ACTIVE = false
local MAX_DISTANCE = 15
local ACTIVATION_DELAY = 0.1
local trackedPrompts = {}
local lastActivation = {}
local connections = {}
local targetNames = {}
local processedPrompts = {}
local scanQueue = {}
local targetNamesCache = {}
local brainrotFolder = nil
local selectedNamesValue = nil
local lastKnownValue = ""
local SCRIPT_LOADED = false

local toggleBtn = container:WaitForChild("Toggle")
local autoBuyBtn = container:WaitForChild("ToggleBT") 
local scrollingFR = container:WaitForChild("ScrollingFrame")
local inf = container:WaitForChild('TextLabel')

local function scanForAvailableNames()
	local foundNames = {}
	for _, name in ipairs(brainrotNames) do
		table.insert(foundNames, name)
	end
	table.sort(foundNames)
	return foundNames
end

local function updateAvailableNames()
	availableNames = scanForAvailableNames()
end

local function setupCommunicationSystem()
	brainrotFolder = ReplicatedStorage:FindFirstChild("BrainrotSystem")
	if not brainrotFolder then
		brainrotFolder = Instance.new("Folder")
		brainrotFolder.Name = "BrainrotSystem"
		brainrotFolder.Parent = ReplicatedStorage
	end

	selectedNamesValue = brainrotFolder:FindFirstChild("SelectedNames")
	if not selectedNamesValue then
		selectedNamesValue = Instance.new("StringValue")
		selectedNamesValue.Name = "SelectedNames"
		selectedNamesValue.Value = ""
		selectedNamesValue.Parent = brainrotFolder
	end
end

local function saveSelectedNames()
	if not selectedNamesValue then return end

	local selectedList = {}
	for name in pairs(selected) do
		table.insert(selectedList, name)
	end

	local joinedNames = table.concat(selectedList, "|||")
	selectedNamesValue.Value = joinedNames
	lastKnownValue = joinedNames
end

local function loadSavedSelection()
	if not selectedNamesValue then return end

	selected = {}
	if selectedNamesValue.Value ~= "" then
		local savedNames = string.split(selectedNamesValue.Value, "|||")
		for _, name in ipairs(savedNames) do
			if name and name ~= "" then
				selected[name] = true
			end
		end
	end
end

local function waitForCommunicationSystem()
	local attempts = 0
	while attempts < 50 do
		brainrotFolder = ReplicatedStorage:FindFirstChild("BrainrotSystem")
		if brainrotFolder then break end
		attempts = attempts + 1
		wait(0.2)
	end

	if not brainrotFolder then return false end

	attempts = 0
	while attempts < 25 do
		selectedNamesValue = brainrotFolder:FindFirstChild("SelectedNames")
		if selectedNamesValue then break end
		attempts = attempts + 1
		wait(0.2)
	end

	return selectedNamesValue ~= nil
end

local function loadSelectedNames()
	if not selectedNamesValue then
		if not waitForCommunicationSystem() then
			return {}
		end
	end

	local currentValue = selectedNamesValue.Value
	if currentValue == "" then
		return {}
	end

	local selectedNames = string.split(currentValue, "|||")
	local validNames = {}

	for _, name in ipairs(selectedNames) do
		if name and name ~= "" then
			table.insert(validNames, name)
		end
	end

	lastKnownValue = currentValue
	return validNames
end

local function updateTargetNames()
	targetNames = {}
	for name in pairs(selected) do
		table.insert(targetNames, name)
	end

	targetNamesCache = {}
	for i, name in pairs(targetNames) do
		targetNamesCache[i] = {
			original = name,
			lower = name:lower()
		}
	end

	if #targetNames == 0 and AUTO_ACTIVATE then
		AUTO_ACTIVATE = false
		stopScript()
	end
end

local function updateButtonAppearance()
	local count = #targetNames
	if AUTO_ACTIVATE and count > 0 then
		autoBuyBtn.Text = ""
		autoBuyBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
		autoBuyBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
	else
		autoBuyBtn.Text = ""
		autoBuyBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
		autoBuyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

local function setupChangeMonitoring()
	if not selectedNamesValue then return end

	selectedNamesValue.Changed:Connect(function(newValue)
		if newValue ~= lastKnownValue then
			lastKnownValue = newValue
			wait(0.1)
			updateTargetNames()
			updateButtonAppearance()
		end
	end)
end

local function isTargetAnimal(animalModel)
	if not animalModel or not animalModel:FindFirstChild("HumanoidRootPart") then 
		return false, nil 
	end

	local humanoidRootPart = animalModel:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return false, nil end

	local info = humanoidRootPart:FindFirstChild("Info")
	if not info then return false, nil end

	local animalOverhead = info:FindFirstChild("AnimalOverhead")
	if not animalOverhead then return false, nil end

	local displayName = animalOverhead:FindFirstChild("DisplayName")
	if not displayName or not displayName.Text then return false, nil end

	local animalName = displayName.Text

	for _, nameData in pairs(targetNamesCache) do
		if animalName == nameData.original then
			return true, nameData.original
		end
	end

	return false, nil
end

local function getAnimalProximityPrompt(animalModel)
	if not animalModel or not animalModel:FindFirstChild("HumanoidRootPart") then 
		return nil 
	end

	local humanoidRootPart = animalModel:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return nil end

	local promptAttachment = humanoidRootPart:FindFirstChild("PromptAttachment")
	if not promptAttachment then return nil end

	local proximityPrompt = promptAttachment:FindFirstChild("ProximityPrompt")
	return proximityPrompt
end

local function activateProximityPrompt(prompt)
	if not prompt or not prompt.Parent or not AUTO_ACTIVATE or #targetNames == 0 then return end

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

local function scanMovingAnimals()
	if not AUTO_ACTIVATE or not character or not humanoidRootPart or #targetNames == 0 then
		return
	end

	local movingAnimals = workspace:FindFirstChild("MovingAnimals")
	if not movingAnimals then return end

	local playerPosition = humanoidRootPart.Position

	for _, animalModel in pairs(movingAnimals:GetChildren()) do
		if animalModel:IsA("Model") then
			local isTarget, foundName = isTargetAnimal(animalModel)
			if isTarget then
				local proximityPrompt = getAnimalProximityPrompt(animalModel)
				if proximityPrompt then
					local modelPosition = getModelPosition(animalModel)
					if modelPosition then
						local distance = (playerPosition - modelPosition).Magnitude
						if distance <= MAX_DISTANCE then
							activateProximityPrompt(proximityPrompt)
						end
					end
				end
			end
		end
	end
end

local function startScript()
	if SCRIPT_ACTIVE or #targetNames == 0 then return end

	SCRIPT_ACTIVE = true

	connections[#connections + 1] = ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if not AUTO_ACTIVATE or #targetNames == 0 then return end

		local animalModel = prompt.Parent.Parent.Parent
		if animalModel and animalModel.Parent and animalModel.Parent.Name == "MovingAnimals" then
			local isTarget, foundName = isTargetAnimal(animalModel)
			if isTarget then
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

	local lastScan = 0
	local lastCleanup = 0

	connections[#connections + 1] = RunService.Heartbeat:Connect(function()
		if not AUTO_ACTIVATE or #targetNames == 0 then return end

		local currentTime = tick()

		if currentTime - lastScan >= 2 then
			lastScan = currentTime
			pcall(scanMovingAnimals)
		end

		if currentTime - lastCleanup >= 15 then
			lastCleanup = currentTime
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
	end)
end

local function stopScript()
	if not SCRIPT_ACTIVE then return end

	SCRIPT_ACTIVE = false

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

local function toggleScript()
	updateTargetNames()

	if #targetNames == 0 then
		AUTO_ACTIVATE = false
		updateButtonAppearance()
		return
	end

	AUTO_ACTIVATE = not AUTO_ACTIVATE
	updateButtonAppearance()

	if AUTO_ACTIVATE then
		startScript()
	else
		stopScript()
	end
end

local function updateCompleteUI()
	local count = 0
	for _ in pairs(selected) do count = count + 1 end

	if count > 0 then
		toggleBtn.Text = "🎯 SELECTED (" .. count .. ")"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
	else
		toggleBtn.Text = "🎯 SELECT ITEMS"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	end

	updateTargetNames()
	updateButtonAppearance()
end

local function hideElementsForSelection()
	autoBuyBtn.Visible = false
	inf.Visible = false
end

local function showElementsAfterSelection()
	autoBuyBtn.Visible = true
	inf.Visible = true
end

local function populateScrolling()
	for _, child in pairs(scrollingFR:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local y = 0
	for _, name in ipairs(availableNames) do
		local btn = Instance.new("TextButton")
		local UICorner = Instance.new('UICorner')
		local UIStroke = Instance.new('UIStroke')
		local UIPadding = Instance.new('UIPadding')

		btn.Name = name
		btn.Position = UDim2.new(0, 0, 0, y)
		btn.Size = UDim2.new(0.973593, 0, 0.0153, 0)
		btn.BackgroundColor3 = Color3.new(0.580392, 0.580392, 0.580392)
		btn.BackgroundTransparency = 0.800000
		btn.BorderColor3 = Color3.new(0.000000, 0.000000, 0.000000)
		btn.BorderSizePixel = 0
		btn.Font = Enum.Font.Arcade
		btn.TextColor3 = Color3.new(1.000000, 1.000000, 1.000000)
		btn.TextScaled = false
		btn.TextSize = 12
		btn.TextWrapped = false
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.RichText = true

		UICorner.CornerRadius = UDim.new(0, 8)
		UICorner.Parent = btn

		UIStroke.Thickness = 1
		UIStroke.Transparency = 0
		UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		UIStroke.Color = Color3.new(1, 1, 1)
		UIStroke.Parent = btn

		UIPadding.PaddingLeft = UDim.new(0, 8)
		UIPadding.PaddingRight = UDim.new(0, 8)
		UIPadding.PaddingTop = UDim.new(0, 4)
		UIPadding.PaddingBottom = UDim.new(0, 4)
		UIPadding.Parent = btn

		btn.Parent = scrollingFR

		if selected[name] then
			btn.BackgroundTransparency = 0.7
			btn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
			btn.Text = "✅ " .. name
		else
			btn.BackgroundTransparency = 0.35
			btn.BackgroundColor3 = Color3.new(0, 0, 0)
			btn.Text = "❌ " .. name
		end

		btn.MouseButton1Click:Connect(function()
			if selected[name] then
				selected[name] = nil
				btn.BackgroundTransparency = 0.35
				btn.BackgroundColor3 = Color3.new(0, 0, 0)
				btn.Text = "❌ " .. name
			else
				selected[name] = true
				btn.BackgroundTransparency = 0.7
				btn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
				btn.Text = "✅ " .. name
			end

			saveSelectedNames()

			local count = 0
			for _ in pairs(selected) do count = count + 1 end

			if count > 0 then
				toggleBtn.Text = "🎯 SELECTED (" .. count .. ")"
				toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
			else
				toggleBtn.Text = "🎯 SELECT ITEMS"
				toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			end

			updateTargetNames()
			updateButtonAppearance()
		end)

		y = y + 32
	end

	scrollingFR.CanvasSize = UDim2.new(0, 0, 0, y)
end

local function showLoadingStatus()
	toggleBtn.Text = "⏳ LOADING..."
	toggleBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 0)
	autoBuyBtn.Visible = false
	inf.Visible = false
end

local function finishLoading()
	SCRIPT_LOADED = true
	updateCompleteUI()
	autoBuyBtn.Visible = true
	inf.Visible = true
end

toggleBtn.MouseButton1Click:Connect(function()
	if not SCRIPT_LOADED then
		toggleBtn.Text = "⚠️ WAIT FOR LOADING!"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
		wait(1.5)
		return
	end

	if scrollingFR.Visible then
		scrollingFR.Visible = false
		showElementsAfterSelection()
		updateCompleteUI()
	else
		updateAvailableNames()
		hideElementsForSelection()
		scrollingFR.Visible = true

		local count = 0
		for _ in pairs(selected) do count = count + 1 end

		if count > 0 then
			toggleBtn.Text = "🎯 SELECTED (" .. count .. ") - CLICK TO CLOSE"
		else
			toggleBtn.Text = "🎯 SELECT ITEMS - CLICK TO CLOSE"
		end
		toggleBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)

		populateScrolling()
	end
end)

autoBuyBtn.MouseButton1Click:Connect(function()
	if not SCRIPT_LOADED then
		return
	end
	toggleScript()
end)

local function onCharacterAdded(newCharacter)
	character = newCharacter
	humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	if AUTO_ACTIVATE then
		stopScript()
		wait(1)
		startScript()
	end
end

player.CharacterAdded:Connect(onCharacterAdded)

game.Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player then
		stopScript()
	end
end)

coroutine.wrap(function()
	showLoadingStatus()

	setupCommunicationSystem()
	wait(0.5)

	loadSavedSelection()
	wait(0.5)

	updateAvailableNames()
	wait(0.5)

	updateTargetNames()
	wait(0.5)

	setupChangeMonitoring()
	updateButtonAppearance()
	wait(0.5)

	finishLoading()

	wait(2)
	if AUTO_ACTIVATE and #targetNames > 0 then
		scanMovingAnimals()
	end
end)()
