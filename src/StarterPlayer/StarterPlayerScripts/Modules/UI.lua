local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local UI = {}

function UI.create(state)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local oldGui = playerGui:FindFirstChild("ControlPanel V.3")
	if oldGui then
		oldGui:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ControlPanel V.3"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	local locationNames = {
		"Island3CavePeakBarrier",
		"Island3CavePeakEnd",
		"Island3RedCave",
	}
	
	local mineralNames = {
		"Floating Crystal",
		"Large Red Crystal",
		"Large Ice Crystal",
		"Medium Red Crystal",
		"Medium Ice Crystal",
		"Small Red Crystal",
	}

	local oreNames = {
		"Heavenite",
		"Gargantuan",
		"Suryafal",
		"Etherealite",
		"Iceite",
		"Velchire",
	}

	local monsterNames = {
		"Elite Orc",
		"Yeti",
		"Common Orc",
	}

	state.selectedLocations = state.selectedLocations or {}
	for _, name in ipairs(locationNames) do
		if state.selectedLocations[name] == nil then
			state.selectedLocations[name] = false
		end
	end

	state.selectedMinerals = state.selectedMinerals or {}
	for _, name in ipairs(mineralNames) do
		if state.selectedMinerals[name] == nil then
			state.selectedMinerals[name] = false
		end
	end

	state.selectedOres = state.selectedOres or {}
	for _, name in ipairs(oreNames) do
		if state.selectedOres[name] == nil then
			state.selectedOres[name] = false
		end
	end

	state.selectedMonsters = state.selectedMonsters or {}
	for _, name in ipairs(monsterNames) do
		if state.selectedMonsters[name] == nil then
			state.selectedMonsters[name] = false
		end
	end

	local function pointInGui(guiObject, x, y)
		local pos = guiObject.AbsolutePosition
		local size = guiObject.AbsoluteSize
		return x >= pos.X and x <= pos.X + size.X and y >= pos.Y and y <= pos.Y + size.Y
	end

	local function makeCorner(parent, radius)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, radius or 6)
		c.Parent = parent
		return c
	end

	local function makeStroke(parent, color, thickness, transparency)
		local s = Instance.new("UIStroke")
		s.Color = color or Color3.fromRGB(90, 90, 90)
		s.Thickness = thickness or 1
		s.Transparency = transparency or 0
		s.Parent = parent
		return s
	end

	local expandedHeight = 950
	local collapsedHeight = 48
	local isCollapsed = false

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 340, 0, expandedHeight)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	frame.BorderSizePixel = 0
	frame.Parent = screenGui
	makeCorner(frame, 10)

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 46)
	header.Position = UDim2.new(0, 0, 0, 0)
	header.BackgroundTransparency = 1
	header.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -90, 1, 0)
	title.Position = UDim2.new(0, 12, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "Control Panel V.3"
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local collapseBtn = Instance.new("TextButton")
	collapseBtn.Size = UDim2.new(0, 34, 0, 34)
	collapseBtn.Position = UDim2.new(1, -78, 0, 6)
	collapseBtn.Text = "—"
	collapseBtn.Font = Enum.Font.GothamBold
	collapseBtn.TextSize = 18
	collapseBtn.TextColor3 = Color3.new(1, 1, 1)
	collapseBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	collapseBtn.BorderSizePixel = 0
	collapseBtn.Parent = header
	makeCorner(collapseBtn, 8)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 34, 0, 34)
	closeBtn.Position = UDim2.new(1, -40, 0, 6)
	closeBtn.Text = "X"
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 16
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = header
	makeCorner(closeBtn, 8)

	local refreshButtons
	local statusLabel

	closeBtn.MouseButton1Click:Connect(function()
		getgenv().RobloxUIRunning = false

		state.autoBoss = false
		state.autoMiner = false
		state.autoPressT = false
		state.autoDefend = false
		state.autoMonsterFarm = false
		state.autoClearTrash = false
		state.isClearing = false
		state.clearStatusText = "Stopped"
		state.autoUseLuckPotion = false
		state.autoBuyLuckPotion = false

		state.autoUseMinerPotion = false
		state.autoBuyMinerPotion = false
		refreshButtons()

		screenGui:Destroy()
	end)

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, 0, 1, -46)
	content.Position = UDim2.new(0, 0, 0, 46)
	content.BackgroundTransparency = 1
	content.ClipsDescendants = false
	content.Parent = frame

	local function makeButton(text, y)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -20, 0, 40)
		btn.Position = UDim2.new(0, 10, 0, y)
		btn.Text = text
		btn.Font = Enum.Font.GothamSemibold
		btn.TextSize = 15
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		btn.BorderSizePixel = 0
		btn.Parent = content
		makeCorner(btn, 8)
		return btn
	end

	local function createMultiSelect(names, selectedMap, y, placeholderText, dropdownHeight)
		local selectWrap = Instance.new("Frame")
		selectWrap.Size = UDim2.new(1, -20, 0, 46)
		selectWrap.Position = UDim2.new(0, 10, 0, y)
		selectWrap.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
		selectWrap.BorderSizePixel = 0
		selectWrap.Parent = content
		makeCorner(selectWrap, 8)
		makeStroke(selectWrap, Color3.fromRGB(75, 75, 75), 1, 0)

		local arrowLabel = Instance.new("TextLabel")
		arrowLabel.Size = UDim2.new(0, 30, 1, 0)
		arrowLabel.Position = UDim2.new(1, -30, 0, 0)
		arrowLabel.BackgroundTransparency = 1
		arrowLabel.Text = "▼"
		arrowLabel.Font = Enum.Font.GothamBold
		arrowLabel.TextSize = 14
		arrowLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		arrowLabel.Parent = selectWrap

		local openBtn = Instance.new("TextButton")
		openBtn.Size = UDim2.new(1, 0, 1, 0)
		openBtn.BackgroundTransparency = 1
		openBtn.Text = ""
		openBtn.Parent = selectWrap

		local tagScroll = Instance.new("ScrollingFrame")
		tagScroll.Size = UDim2.new(1, -38, 1, -8)
		tagScroll.Position = UDim2.new(0, 6, 0, 4)
		tagScroll.BackgroundTransparency = 1
		tagScroll.BorderSizePixel = 0
		tagScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		tagScroll.ScrollBarThickness = 3
		tagScroll.ScrollingDirection = Enum.ScrollingDirection.X
		tagScroll.Parent = selectWrap

		local tagLayout = Instance.new("UIListLayout")
		tagLayout.FillDirection = Enum.FillDirection.Horizontal
		tagLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		tagLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		tagLayout.Padding = UDim.new(0, 6)
		tagLayout.Parent = tagScroll

		local placeholder = Instance.new("TextLabel")
		placeholder.Size = UDim2.new(1, 0, 1, 0)
		placeholder.BackgroundTransparency = 1
		placeholder.Text = placeholderText
		placeholder.Font = Enum.Font.Gotham
		placeholder.TextSize = 14
		placeholder.TextColor3 = Color3.fromRGB(180, 180, 180)
		placeholder.TextXAlignment = Enum.TextXAlignment.Left
		placeholder.Parent = tagScroll

		local dropdown = Instance.new("Frame")
		dropdown.Size = UDim2.new(1, -20, 0, 0)
		dropdown.Position = UDim2.new(0, 10, 0, y + 51)
		dropdown.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		dropdown.BorderSizePixel = 0
		dropdown.ClipsDescendants = true
		dropdown.Visible = true
		dropdown.ZIndex = 20
		dropdown.Parent = content
		makeCorner(dropdown, 8)
		makeStroke(dropdown, Color3.fromRGB(80, 80, 80), 1, 0)

		local searchBox = Instance.new("TextBox")
		searchBox.Size = UDim2.new(1, -12, 0, 34)
		searchBox.Position = UDim2.new(0, 6, 0, 6)
		searchBox.PlaceholderText = "Search..."
		searchBox.Text = ""
		searchBox.ClearTextOnFocus = false
		searchBox.Font = Enum.Font.Gotham
		searchBox.TextSize = 14
		searchBox.TextColor3 = Color3.new(1, 1, 1)
		searchBox.PlaceholderColor3 = Color3.fromRGB(180, 180, 180)
		searchBox.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
		searchBox.BorderSizePixel = 0
		searchBox.ZIndex = 21
		searchBox.Parent = dropdown
		makeCorner(searchBox, 6)

		local listScroll = Instance.new("ScrollingFrame")
		listScroll.Size = UDim2.new(1, -12, 1, -46)
		listScroll.Position = UDim2.new(0, 6, 0, 40)
		listScroll.BackgroundTransparency = 1
		listScroll.BorderSizePixel = 0
		listScroll.ScrollBarThickness = 4
		listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		listScroll.ZIndex = 21
		listScroll.Parent = dropdown

		local listLayout = Instance.new("UIListLayout")
		listLayout.Padding = UDim.new(0, 4)
		listLayout.Parent = listScroll

		local optionButtons = {}
		local dropdownOpen = false
		local outsideConnection = nil

		local function getSelectedNames()
			local results = {}
			for _, name in ipairs(names) do
				if selectedMap[name] then
					table.insert(results, name)
				end
			end
			return results
		end

		local function clearTags()
			for _, child in ipairs(tagScroll:GetChildren()) do
				if child:IsA("Frame") then
					child:Destroy()
				end
			end
		end

		local function refreshTags()
			clearTags()

			local selected = getSelectedNames()
			placeholder.Visible = (#selected == 0)

			for _, name in ipairs(selected) do
				local tag = Instance.new("Frame")
				tag.BackgroundColor3 = Color3.fromRGB(60, 100, 180)
				tag.BorderSizePixel = 0
				tag.AutomaticSize = Enum.AutomaticSize.X
				tag.Size = UDim2.new(0, 0, 0, 28)
				tag.Parent = tagScroll
				makeCorner(tag, 14)

				local innerPad = Instance.new("UIPadding")
				innerPad.PaddingLeft = UDim.new(0, 10)
				innerPad.PaddingRight = UDim.new(0, 8)
				innerPad.Parent = tag

				local tagLayoutInner = Instance.new("UIListLayout")
				tagLayoutInner.FillDirection = Enum.FillDirection.Horizontal
				tagLayoutInner.HorizontalAlignment = Enum.HorizontalAlignment.Left
				tagLayoutInner.VerticalAlignment = Enum.VerticalAlignment.Center
				tagLayoutInner.Padding = UDim.new(0, 6)
				tagLayoutInner.Parent = tag

				local tagLabel = Instance.new("TextLabel")
				tagLabel.BackgroundTransparency = 1
				tagLabel.AutomaticSize = Enum.AutomaticSize.X
				tagLabel.Size = UDim2.new(0, 0, 1, 0)
				tagLabel.Text = name
				tagLabel.Font = Enum.Font.GothamMedium
				tagLabel.TextSize = 13
				tagLabel.TextColor3 = Color3.new(1, 1, 1)
				tagLabel.Parent = tag

				local removeBtn = Instance.new("TextButton")
				removeBtn.BackgroundTransparency = 1
				removeBtn.Size = UDim2.new(0, 16, 0, 16)
				removeBtn.Text = "×"
				removeBtn.Font = Enum.Font.GothamBold
				removeBtn.TextSize = 14
				removeBtn.TextColor3 = Color3.new(1, 1, 1)
				removeBtn.Parent = tag

				removeBtn.MouseButton1Click:Connect(function()
					selectedMap[name] = false
					if optionButtons[name] then
						local btn = optionButtons[name]
						btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
						local check = btn:FindFirstChild("CheckLabel")
						if check then
							check.Text = ""
						end
					end
					refreshTags()
				end)
			end

			task.defer(function()
				local contentWidth = tagLayout.AbsoluteContentSize.X
				tagScroll.CanvasSize = UDim2.new(0, math.max(contentWidth + 10, tagScroll.AbsoluteSize.X), 0, 0)
			end)
		end

		local function refreshOptionVisual(name)
			local btn = optionButtons[name]
			if not btn then
				return
			end

			local selected = selectedMap[name]
			btn.BackgroundColor3 = selected and Color3.fromRGB(45, 120, 70) or Color3.fromRGB(60, 60, 60)

			local check = btn:FindFirstChild("CheckLabel")
			if check then
				check.Text = selected and "✓" or ""
			end
		end

		local function rebuildOptions()
			for _, child in ipairs(listScroll:GetChildren()) do
				if child:IsA("TextButton") then
					child:Destroy()
				end
			end
			optionButtons = {}

			local keyword = string.lower(searchBox.Text or "")

			for _, name in ipairs(names) do
				if keyword == "" or string.find(string.lower(name), keyword, 1, true) then
					local option = Instance.new("TextButton")
					option.Size = UDim2.new(1, 0, 0, 34)
					option.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
					option.BorderSizePixel = 0
					option.Text = ""
					option.ZIndex = 21
					option.Parent = listScroll
					makeCorner(option, 6)

					local checkLabel = Instance.new("TextLabel")
					checkLabel.Name = "CheckLabel"
					checkLabel.Size = UDim2.new(0, 24, 1, 0)
					checkLabel.Position = UDim2.new(0, 8, 0, 0)
					checkLabel.BackgroundTransparency = 1
					checkLabel.Font = Enum.Font.GothamBold
					checkLabel.TextSize = 16
					checkLabel.TextColor3 = Color3.new(1, 1, 1)
					checkLabel.Parent = option

					local label = Instance.new("TextLabel")
					label.Size = UDim2.new(1, -40, 1, 0)
					label.Position = UDim2.new(0, 32, 0, 0)
					label.BackgroundTransparency = 1
					label.Text = name
					label.Font = Enum.Font.Gotham
					label.TextSize = 14
					label.TextColor3 = Color3.new(1, 1, 1)
					label.TextXAlignment = Enum.TextXAlignment.Left
					label.Parent = option

					option.MouseButton1Click:Connect(function()
						selectedMap[name] = not selectedMap[name]
						refreshOptionVisual(name)
						refreshTags()
					end)

					optionButtons[name] = option
					refreshOptionVisual(name)
				end
			end

			task.defer(function()
				listScroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 4)
			end)
		end

		local function closeDropdown()
			if not dropdownOpen then
				return
			end
			dropdownOpen = false
			arrowLabel.Text = "▼"
			dropdown:TweenSize(
				UDim2.new(1, -20, 0, 0),
				Enum.EasingDirection.Out,
				Enum.EasingStyle.Quad,
				0.15,
				true
			)
			if outsideConnection then
				outsideConnection:Disconnect()
				outsideConnection = nil
			end
		end

		local function openDropdown()
			if dropdownOpen then
				return
			end
			dropdownOpen = true
			arrowLabel.Text = "▲"
			rebuildOptions()
			dropdown:TweenSize(
				UDim2.new(1, -20, 0, dropdownHeight or 190),
				Enum.EasingDirection.Out,
				Enum.EasingStyle.Quad,
				0.15,
				true
			)

			outsideConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if gameProcessed or isCollapsed then
					return
				end

				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch then
					local pos = UserInputService:GetMouseLocation()
					local x = pos.X
					local y = pos.Y

					local insideSelect = pointInGui(selectWrap, x, y)
					local insideDropdown = pointInGui(dropdown, x, y)

					if not insideSelect and not insideDropdown then
						closeDropdown()
					end
				end
			end)
		end

		openBtn.MouseButton1Click:Connect(function()
			if isCollapsed then
				return
			end

			if dropdownOpen then
				closeDropdown()
			else
				openDropdown()
				task.wait()
				searchBox:CaptureFocus()
			end
		end)

		searchBox:GetPropertyChangedSignal("Text"):Connect(rebuildOptions)

		refreshTags()
		closeDropdown()

		return {
			selectWrap = selectWrap,
			dropdown = dropdown,
			refreshTags = refreshTags,
			close = closeDropdown,
		}
	end

	local bossBtn = makeButton("Auto Boss: OFF", 10)
	local tBtn = makeButton("Auto T: OFF", 60)
	local minerBtn = makeButton("Auto Miner: OFF", 110)
	local defendBtn = makeButton("Auto Defend: OFF", 160)
	local clearBtn = makeButton("Auto Clear Trash: OFF", 210)
	local monsterFarmBtn = makeButton("Auto Monster Farm: OFF", 260)
	local locationSelect = createMultiSelect(
		locationNames,
		state.selectedLocations,
		315,
		"Select locations...",
		190
	)

	local mineralSelect = createMultiSelect(
		mineralNames,
		state.selectedMinerals,
		370,
		"Select minerals...",
		190
	)

	local oreSelect = createMultiSelect(
		oreNames,
		state.selectedOres,
		425,
		"Select ores...",
		190
	)

	local monsterSelect = createMultiSelect(
		monsterNames,
		state.selectedMonsters,
		480,
		"Select monsters...",
		190
	)

	local luckAutoBtn = makeButton("Auto Luck Potion: OFF", 530)
	local luckBuyBtn = makeButton("Auto Buy Luck: OFF", 580)

	local minerPotionBtn = makeButton("Auto Miner Potion: OFF", 630)
	local minerBuyBtn = makeButton("Auto Buy Miner: OFF", 690)

	-- local function refreshButtons()
	refreshButtons = function()
		local minerText = state.autoMiner and "ON" or "OFF"
		local defendText = state.autoDefend and "ON" or "OFF"
		local monsterFarmText = state.autoMonsterFarm and "ON" or "OFF"

		if state.isClearing then
			minerText = "WAIT"
			defendText = "WAIT"
		end

		bossBtn.Text = "Auto Boss: " .. (state.autoBoss and "ON" or "OFF")
		bossBtn.BackgroundColor3 = state.autoBoss
			and Color3.fromRGB(40, 140, 70)
			or Color3.fromRGB(60, 60, 60)

		minerBtn.Text = "Auto Miner: " .. minerText
		minerBtn.BackgroundColor3 = state.autoMiner
			and Color3.fromRGB(40, 140, 70)
			or Color3.fromRGB(60, 60, 60)

		tBtn.Text = "Auto T: " .. (state.autoPressT and "ON" or "OFF")
		tBtn.BackgroundColor3 = state.autoPressT
			and Color3.fromRGB(40, 140, 70)
			or Color3.fromRGB(60, 60, 60)

		defendBtn.Text = "Auto Defend: " .. defendText
		defendBtn.BackgroundColor3 = state.autoDefend
			and Color3.fromRGB(40, 140, 70)
			or Color3.fromRGB(60, 60, 60)

		clearBtn.Text = "Auto Clear Trash: " .. (state.autoClearTrash and "ON" or "OFF")
		clearBtn.BackgroundColor3 = state.autoClearTrash
			and Color3.fromRGB(40, 140, 70)
			or Color3.fromRGB(60, 60, 60)

		monsterFarmBtn.Text = "Auto Monster Farm: " .. monsterFarmText
		monsterFarmBtn.BackgroundColor3 = state.autoMonsterFarm
			and Color3.fromRGB(40, 140, 70)
			or Color3.fromRGB(60, 60, 60)

		luckAutoBtn.Text = "Auto Luck Potion: " .. (state.autoUseLuckPotion and "ON" or "OFF")
		luckAutoBtn.BackgroundColor3 = state.autoUseLuckPotion
			and Color3.fromRGB(40,140,70)
			or Color3.fromRGB(60,60,60)

		luckBuyBtn.Text = "Auto Buy Luck: " .. (state.autoBuyLuckPotion and "ON" or "OFF")
		luckBuyBtn.BackgroundColor3 = state.autoBuyLuckPotion
			and Color3.fromRGB(40,140,70)
			or Color3.fromRGB(60,60,60)

		minerPotionBtn.Text = "Auto Miner Potion: " .. (state.autoUseMinerPotion and "ON" or "OFF")
		minerPotionBtn.BackgroundColor3 = state.autoUseMinerPotion
			and Color3.fromRGB(40,140,70)
			or Color3.fromRGB(60,60,60)

		minerBuyBtn.Text = "Auto Buy Miner: " .. (state.autoBuyMinerPotion and "ON" or "OFF")
		minerBuyBtn.BackgroundColor3 = state.autoBuyMinerPotion
			and Color3.fromRGB(40,140,70)
			or Color3.fromRGB(60,60,60)
			
		if statusLabel then
			if state.isClearing then
				statusLabel.Text = "Status: " .. (state.clearStatusText ~= "" and state.clearStatusText or "Clearing...")
				statusLabel.TextColor3 = Color3.fromRGB(255, 210, 120)
			else
				statusLabel.Text = "Status: Idle"
				statusLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
			end
		end
	end

	bossBtn.MouseButton1Click:Connect(function()
		state.autoBoss = not state.autoBoss
		refreshButtons()
	end)

	minerBtn.MouseButton1Click:Connect(function()
		state.autoMiner = not state.autoMiner
		if state.autoMiner then
			state.autoMonsterFarm = false
		end
		refreshButtons()
	end)

	tBtn.MouseButton1Click:Connect(function()
		state.autoPressT = not state.autoPressT
		refreshButtons()
	end)

	defendBtn.MouseButton1Click:Connect(function()
		state.autoDefend = not state.autoDefend
		refreshButtons()
	end)

	clearBtn.MouseButton1Click:Connect(function()
		state.autoClearTrash = not state.autoClearTrash
		refreshButtons()
	end)

	monsterFarmBtn.MouseButton1Click:Connect(function()
		state.autoMonsterFarm = not state.autoMonsterFarm
		if state.autoMonsterFarm then
			state.autoMiner = false
		end
		refreshButtons()
	end)

	luckAutoBtn.MouseButton1Click:Connect(function()
		state.autoUseLuckPotion = not state.autoUseLuckPotion
		refreshButtons()
	end)

	luckBuyBtn.MouseButton1Click:Connect(function()
		state.autoBuyLuckPotion = not state.autoBuyLuckPotion
		refreshButtons()
	end)

	minerPotionBtn.MouseButton1Click:Connect(function()
		state.autoUseMinerPotion = not state.autoUseMinerPotion
		refreshButtons()
	end)

	minerBuyBtn.MouseButton1Click:Connect(function()
		state.autoBuyMinerPotion = not state.autoBuyMinerPotion
		refreshButtons()
	end)

	local dragToggle = nil
	local dragInput = nil
	local dragStart = nil
	local startPos = nil

	statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -20, 0, 24)
	statusLabel.Position = UDim2.new(0, 10, 0, 285)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 13
	statusLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Text = "Status: Idle"
	statusLabel.Parent = content


	local function updateDrag(input)
		local delta = input.Position - dragStart
		frame.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
	end

	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragToggle = true
			dragStart = input.Position
			startPos = frame.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragToggle = false
				end
			end)
		end
	end)

	header.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragToggle then
			updateDrag(input)
		end
	end)

	local function setCollapsed(collapsed)
		isCollapsed = collapsed

		if collapsed then
			locationSelect.close()
			mineralSelect.close()
			oreSelect.close()
			monsterSelect.close()
			content.Visible = false
			frame:TweenSize(
				UDim2.new(0, 340, 0, collapsedHeight),
				Enum.EasingDirection.Out,
				Enum.EasingStyle.Quad,
				0.15,
				true
			)
			collapseBtn.Text = "+"
		else
			content.Visible = true
			frame:TweenSize(
				UDim2.new(0, 340, 0, expandedHeight),
				Enum.EasingDirection.Out,
				Enum.EasingStyle.Quad,
				0.15,
				true
			)
			collapseBtn.Text = "—"
		end
	end

	collapseBtn.MouseButton1Click:Connect(function()
		setCollapsed(not isCollapsed)
	end)

	refreshButtons()
	setCollapsed(false)

	task.spawn(function()
		while getgenv().RobloxUIRunning and screenGui.Parent do
			refreshButtons()
			task.wait(0.2)
		end
	end)

	return screenGui
end

return UI