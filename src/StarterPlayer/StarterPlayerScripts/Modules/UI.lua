local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local UI = {}

function UI.create(state)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local oldGui = playerGui:FindFirstChild("ControlPanel V.7")
	if oldGui then
		oldGui:Destroy()
	end

	-------------------------------------------------
	-- Data
	-------------------------------------------------
	local locationNames = {
		"2s",
		"I4_HolyCave_03_1",
		"I4_HolyCave_03_2",
		"Island3CavePeakBarrier",
		"Island3CavePeakEnd",
		"Island3RedCave",
	}

	local mineralNames = {
		"Blossom Boulder",
		"Glowy Rock",
		"Floating Crystal",
		"Heart Of The Island",
		"Large Red Crystal",
		"Large Ice Crystal",
		"Medium Red Crystal",
		"Medium Ice Crystal",
		"Small Red Crystal",
		"Small Ice Crystal",
	}

	local oreNames = {
		"Onyx",
		"Heavenly Orb",
		"Lucky Cat",
		"Heavenite",
		"Heart Of The Island",
		"Stolen Heart",
		"Gargantuan",
		"Duranite",
		"Suryafal",
		"Etherealite",
		"Iceite",
		"Velchire",
	}

	local monsterNames = {
		"Hellflame Oni",
		"Warlord Oni",
		"Frostburn Oni",
		"Brute Oni",

		"Monk Panda",
		"Samurai Ape",
		"Savage Ape",
		"Mountain Ape",

		"Chuthlu",
		"Skeleton Pirate",
		"Elite Orc",
		"Yeti",
		"Common Orc",

		"Crystal Spider",
		"Diamond Spider",
		"Prismarine Spider",
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

	-------------------------------------------------
	-- GUI Root
	-------------------------------------------------
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ControlPanel V.7"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-------------------------------------------------
	-- Helpers
	-------------------------------------------------
	local function makeCorner(parent, radius)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, radius or 8)
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

	local function makeGradient(parent, colorA, colorB, rotation)
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, colorA),
			ColorSequenceKeypoint.new(1, colorB),
		})
		g.Rotation = rotation or 90
		g.Parent = parent
		return g
	end

	local function pointInGui(guiObject, x, y)
		local pos = guiObject.AbsolutePosition
		local size = guiObject.AbsoluteSize
		return x >= pos.X and x <= pos.X + size.X and y >= pos.Y and y <= pos.Y + size.Y
	end

	local function normalizeName(name)
		name = tostring(name or "")
		name = string.lower(name)
		name = name:gsub("%d+$", "")
		name = name:gsub("^%s+", "")
		name = name:gsub("%s+$", "")
		return name
	end

	local function getCharacterParts()
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:FindFirstChild("Humanoid")
		local hrp = character:FindFirstChild("HumanoidRootPart")
		return character, humanoid, hrp
	end

	local function hasAliveMonster(monsterName)
		local living = workspace:FindFirstChild("Living")
		if not living then
			return false
		end

		local target = normalizeName(monsterName)

		for _, mob in ipairs(living:GetChildren()) do
			if mob:IsA("Model") and normalizeName(mob.Name) == target then
				local hum = mob:FindFirstChildOfClass("Humanoid") or mob:FindFirstChildWhichIsA("Humanoid", true)
				if not hum or hum.Health > 0 then
					return true
				end
			end
		end

		return false
	end

	local function hasAliveMineral(mineralName)
		local rocks = workspace:FindFirstChild("Rocks")
		if not rocks then
			return false
		end

		local target = normalizeName(mineralName)

		for _, mapFolder in ipairs(rocks:GetChildren()) do
			for _, obj in ipairs(mapFolder:GetDescendants()) do
				if normalizeName(obj.Name) == target then
					local hpAttr = obj:GetAttribute("Health")
					if type(hpAttr) == "number" then
						if hpAttr > 0 then
							return true
						end
					else
						local hp = obj:FindFirstChild("Health")
						if hp and (hp:IsA("NumberValue") or hp:IsA("IntValue")) then
							if hp.Value > 0 then
								return true
							end
						else
							return true
						end
					end
				end
			end
		end

		return false
	end

	local function detectCurrentWorldName()
		local hasSmallIceCrystal = hasAliveMineral("Small Ice Crystal")
		local hasCrystalSpider = hasAliveMonster("Crystal Spider")

		if hasSmallIceCrystal and hasCrystalSpider then
			return "world3"
		end

		local hasGlowyRock = hasAliveMineral("Glowy Rock")
		local hasBruteOni = hasAliveMonster("Brute Oni")

		if hasGlowyRock and hasBruteOni then
			return "world4"
		end

		return "unknown"
	end

	-------------------------------------------------
	-- Window
	-------------------------------------------------
	local expandedSize = UDim2.new(0, 760, 0, 840)
	local collapsedSize = UDim2.new(0, 760, 0, 58)
	local maximizedSize = UDim2.new(1, -30, 1, -30)

	local isCollapsed = false
	local isMaximized = false

	local frame = Instance.new("Frame")
	frame.Name = "MainFrame"
	frame.Size = expandedSize
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.BackgroundColor3 = Color3.fromRGB(23, 26, 34)
	frame.BorderSizePixel = 0
	frame.Parent = screenGui
	makeCorner(frame, 14)
	makeStroke(frame, Color3.fromRGB(72, 82, 102), 1.2, 0.08)
	makeGradient(frame, Color3.fromRGB(34, 39, 50), Color3.fromRGB(20, 23, 30), 90)

	local storedPosition = frame.Position
	local storedSize = frame.Size

	-------------------------------------------------
	-- Header
	-------------------------------------------------
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 52)
	header.BackgroundTransparency = 1
	header.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -140, 1, 0)
	title.Position = UDim2.new(0, 14, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "Control Panel V.7"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = Color3.fromRGB(245, 247, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local function createHeaderButton(text, xOffset, bgColor)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 34, 0, 34)
		btn.Position = UDim2.new(1, xOffset, 0, 9)
		btn.BackgroundColor3 = bgColor
		btn.BorderSizePixel = 0
		btn.Text = text
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 16
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Parent = header
		makeCorner(btn, 9)
		makeStroke(btn, Color3.fromRGB(255, 255, 255), 1, 0.85)
		return btn
	end

	local collapseBtn = createHeaderButton("_", -116, Color3.fromRGB(69, 93, 182))
	local maxBtn = createHeaderButton("□", -78, Color3.fromRGB(55, 138, 95))
	local closeBtn = createHeaderButton("X", -40, Color3.fromRGB(182, 63, 63))

	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(1, -20, 0, 1)
	divider.Position = UDim2.new(0, 10, 0, 52)
	divider.BackgroundColor3 = Color3.fromRGB(60, 68, 84)
	divider.BorderSizePixel = 0
	divider.Parent = frame

	-------------------------------------------------
	-- Status Bar
	-------------------------------------------------
	local statusBar = Instance.new("Frame")
	statusBar.Size = UDim2.new(1, -20, 0, 72)
	statusBar.Position = UDim2.new(0, 10, 0, 62)
	statusBar.BackgroundColor3 = Color3.fromRGB(28, 32, 41)
	statusBar.BorderSizePixel = 0
	statusBar.Parent = frame
	makeCorner(statusBar, 12)
	makeStroke(statusBar, Color3.fromRGB(76, 85, 102), 1, 0.12)

	local worldTitle = Instance.new("TextLabel")
	worldTitle.Size = UDim2.new(0, 100, 0, 18)
	worldTitle.Position = UDim2.new(0, 14, 0, 10)
	worldTitle.BackgroundTransparency = 1
	worldTitle.Text = "Location"
	worldTitle.Font = Enum.Font.GothamMedium
	worldTitle.TextSize = 12
	worldTitle.TextColor3 = Color3.fromRGB(168, 178, 196)
	worldTitle.TextXAlignment = Enum.TextXAlignment.Left
	worldTitle.Parent = statusBar

	local worldValue = Instance.new("TextLabel")
	worldValue.Size = UDim2.new(0.4, 0, 0, 26)
	worldValue.Position = UDim2.new(0, 14, 0, 28)
	worldValue.BackgroundTransparency = 1
	worldValue.Text = "unknown"
	worldValue.Font = Enum.Font.GothamBold
	worldValue.TextSize = 18
	worldValue.TextColor3 = Color3.fromRGB(240, 244, 255)
	worldValue.TextXAlignment = Enum.TextXAlignment.Left
	worldValue.Parent = statusBar

	local statusTitle = Instance.new("TextLabel")
	statusTitle.Size = UDim2.new(0, 100, 0, 18)
	statusTitle.Position = UDim2.new(0.48, 0, 0, 10)
	statusTitle.BackgroundTransparency = 1
	statusTitle.Text = "Status"
	statusTitle.Font = Enum.Font.GothamMedium
	statusTitle.TextSize = 12
	statusTitle.TextColor3 = Color3.fromRGB(168, 178, 196)
	statusTitle.TextXAlignment = Enum.TextXAlignment.Left
	statusTitle.Parent = statusBar

	local statusValue = Instance.new("TextLabel")
	statusValue.Size = UDim2.new(0.48, -14, 0, 26)
	statusValue.Position = UDim2.new(0.48, 0, 0, 28)
	statusValue.BackgroundTransparency = 1
	statusValue.Text = "Idle"
	statusValue.Font = Enum.Font.GothamBold
	statusValue.TextSize = 16
	statusValue.TextColor3 = Color3.fromRGB(240, 244, 255)
	statusValue.TextXAlignment = Enum.TextXAlignment.Left
	statusValue.Parent = statusBar

	-------------------------------------------------
	-- Content Area
	-------------------------------------------------
	local contentHolder = Instance.new("Frame")
	contentHolder.Name = "ContentHolder"
	contentHolder.Size = UDim2.new(1, -20, 1, -146)
	contentHolder.Position = UDim2.new(0, 10, 0, 144)
	contentHolder.BackgroundTransparency = 1
	contentHolder.Parent = frame

	local function makeButton(parent, text, height)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, height or 40)
		btn.BackgroundColor3 = Color3.fromRGB(52, 58, 72)
		btn.BorderSizePixel = 0
		btn.Text = text
		btn.Font = Enum.Font.GothamSemibold
		btn.TextSize = 15
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Parent = parent
		makeCorner(btn, 10)
		makeStroke(btn, Color3.fromRGB(86, 96, 116), 1, 0.08)
		return btn
	end

	local function createSection(parent, titleText)
		local section = Instance.new("Frame")
		section.AutomaticSize = Enum.AutomaticSize.Y
		section.Size = UDim2.new(1, 0, 0, 10)
		section.BackgroundColor3 = Color3.fromRGB(28, 32, 41)
		section.BorderSizePixel = 0
		section.Parent = parent
		makeCorner(section, 12)
		makeStroke(section, Color3.fromRGB(76, 85, 102), 1, 0.12)

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 10)
		pad.PaddingBottom = UDim.new(0, 10)
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = section

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 8)
		layout.Parent = section

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Size = UDim2.new(1, 0, 0, 20)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Text = titleText
		titleLabel.Font = Enum.Font.GothamBold
		titleLabel.TextSize = 14
		titleLabel.TextColor3 = Color3.fromRGB(243, 246, 255)
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.Parent = section

		return section
	end

	local function createMultiSelect(parent, names, selectedMap, placeholderText, dropdownHeight)
		local wrap = Instance.new("Frame")
		wrap.Size = UDim2.new(1, 0, 0, 46)
		wrap.BackgroundColor3 = Color3.fromRGB(39, 43, 54)
		wrap.BorderSizePixel = 0
		wrap.Parent = parent
		makeCorner(wrap, 10)
		makeStroke(wrap, Color3.fromRGB(84, 94, 112), 1, 0.12)

		local tagScroll = Instance.new("ScrollingFrame")
		tagScroll.Size = UDim2.new(1, -38, 1, -8)
		tagScroll.Position = UDim2.new(0, 6, 0, 4)
		tagScroll.BackgroundTransparency = 1
		tagScroll.BorderSizePixel = 0
		tagScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		tagScroll.ScrollBarThickness = 3
		tagScroll.ScrollingDirection = Enum.ScrollingDirection.X
		tagScroll.Parent = wrap

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
		placeholder.TextSize = 13
		placeholder.TextColor3 = Color3.fromRGB(175, 184, 200)
		placeholder.TextXAlignment = Enum.TextXAlignment.Left
		placeholder.Parent = tagScroll

		local arrowLabel = Instance.new("TextLabel")
		arrowLabel.Size = UDim2.new(0, 28, 1, 0)
		arrowLabel.Position = UDim2.new(1, -30, 0, 0)
		arrowLabel.BackgroundTransparency = 1
		arrowLabel.Text = "▼"
		arrowLabel.Font = Enum.Font.GothamBold
		arrowLabel.TextSize = 13
		arrowLabel.TextColor3 = Color3.fromRGB(225, 232, 245)
		arrowLabel.Parent = wrap

		local openBtn = Instance.new("TextButton")
		openBtn.Size = UDim2.new(1, 0, 1, 0)
		openBtn.BackgroundTransparency = 1
		openBtn.Text = ""
		openBtn.Parent = wrap

		local dropdown = Instance.new("Frame")
		dropdown.Size = UDim2.new(1, 0, 0, 0)
		dropdown.BackgroundColor3 = Color3.fromRGB(31, 35, 45)
		dropdown.BorderSizePixel = 0
		dropdown.ClipsDescendants = true
		dropdown.Parent = parent
		makeCorner(dropdown, 10)
		makeStroke(dropdown, Color3.fromRGB(84, 94, 112), 1, 0.12)

		local searchBox = Instance.new("TextBox")
		searchBox.Size = UDim2.new(1, -12, 0, 34)
		searchBox.Position = UDim2.new(0, 6, 0, 6)
		searchBox.PlaceholderText = "Search..."
		searchBox.Text = ""
		searchBox.ClearTextOnFocus = false
		searchBox.Font = Enum.Font.Gotham
		searchBox.TextSize = 13
		searchBox.TextColor3 = Color3.new(1, 1, 1)
		searchBox.PlaceholderColor3 = Color3.fromRGB(180, 188, 202)
		searchBox.BackgroundColor3 = Color3.fromRGB(49, 54, 66)
		searchBox.BorderSizePixel = 0
		searchBox.Parent = dropdown
		makeCorner(searchBox, 8)

		local listScroll = Instance.new("ScrollingFrame")
		listScroll.Size = UDim2.new(1, -12, 1, -46)
		listScroll.Position = UDim2.new(0, 6, 0, 40)
		listScroll.BackgroundTransparency = 1
		listScroll.BorderSizePixel = 0
		listScroll.ScrollBarThickness = 4
		listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
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

		local function refreshTags()
			for _, child in ipairs(tagScroll:GetChildren()) do
				if child:IsA("Frame") then
					child:Destroy()
				end
			end

			local selected = getSelectedNames()
			placeholder.Visible = (#selected == 0)

			for _, name in ipairs(selected) do
				local tag = Instance.new("Frame")
				tag.BackgroundColor3 = Color3.fromRGB(61, 96, 185)
				tag.BorderSizePixel = 0
				tag.AutomaticSize = Enum.AutomaticSize.X
				tag.Size = UDim2.new(0, 0, 0, 26)
				tag.Parent = tagScroll
				makeCorner(tag, 13)

				local tagPad = Instance.new("UIPadding")
				tagPad.PaddingLeft = UDim.new(0, 10)
				tagPad.PaddingRight = UDim.new(0, 8)
				tagPad.Parent = tag

				local innerLayout = Instance.new("UIListLayout")
				innerLayout.FillDirection = Enum.FillDirection.Horizontal
				innerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
				innerLayout.Padding = UDim.new(0, 6)
				innerLayout.Parent = tag

				local tagLabel = Instance.new("TextLabel")
				tagLabel.BackgroundTransparency = 1
				tagLabel.AutomaticSize = Enum.AutomaticSize.X
				tagLabel.Size = UDim2.new(0, 0, 1, 0)
				tagLabel.Text = name
				tagLabel.Font = Enum.Font.GothamMedium
				tagLabel.TextSize = 12
				tagLabel.TextColor3 = Color3.new(1, 1, 1)
				tagLabel.Parent = tag

				local removeBtn = Instance.new("TextButton")
				removeBtn.BackgroundTransparency = 1
				removeBtn.Size = UDim2.new(0, 14, 0, 14)
				removeBtn.Text = "×"
				removeBtn.Font = Enum.Font.GothamBold
				removeBtn.TextSize = 13
				removeBtn.TextColor3 = Color3.new(1, 1, 1)
				removeBtn.Parent = tag

				removeBtn.MouseButton1Click:Connect(function()
					selectedMap[name] = false
					if optionButtons[name] then
						local btn = optionButtons[name]
						btn.BackgroundColor3 = Color3.fromRGB(55, 60, 72)
						local check = btn:FindFirstChild("CheckLabel")
						if check then
							check.Text = ""
						end
					end
					refreshTags()
				end)
			end

			task.defer(function()
				tagScroll.CanvasSize = UDim2.new(0, math.max(tagLayout.AbsoluteContentSize.X + 10, tagScroll.AbsoluteSize.X), 0, 0)
			end)
		end

		local function refreshOptionVisual(name)
			local btn = optionButtons[name]
			if not btn then
				return
			end

			local selected = selectedMap[name]
			btn.BackgroundColor3 = selected and Color3.fromRGB(47, 122, 74) or Color3.fromRGB(55, 60, 72)

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
					option.BackgroundColor3 = Color3.fromRGB(55, 60, 72)
					option.BorderSizePixel = 0
					option.Text = ""
					option.Parent = listScroll
					makeCorner(option, 8)

					local checkLabel = Instance.new("TextLabel")
					checkLabel.Name = "CheckLabel"
					checkLabel.Size = UDim2.new(0, 24, 1, 0)
					checkLabel.Position = UDim2.new(0, 8, 0, 0)
					checkLabel.BackgroundTransparency = 1
					checkLabel.Font = Enum.Font.GothamBold
					checkLabel.TextSize = 15
					checkLabel.TextColor3 = Color3.new(1, 1, 1)
					checkLabel.Parent = option

					local label = Instance.new("TextLabel")
					label.Size = UDim2.new(1, -40, 1, 0)
					label.Position = UDim2.new(0, 32, 0, 0)
					label.BackgroundTransparency = 1
					label.Text = name
					label.Font = Enum.Font.Gotham
					label.TextSize = 13
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
				UDim2.new(1, 0, 0, 0),
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
				UDim2.new(1, 0, 0, dropdownHeight or 190),
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

					local insideSelect = pointInGui(wrap, x, y)
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
			close = closeDropdown,
			refreshTags = refreshTags,
			wrap = wrap,
			dropdown = dropdown,
		}
	end

	-------------------------------------------------
	-- Top Full Width Buttons
	-------------------------------------------------
	local topStack = Instance.new("Frame")
	topStack.Size = UDim2.new(1, 0, 0, 92)
	topStack.BackgroundTransparency = 1
	topStack.Parent = contentHolder

	local topLayout = Instance.new("UIListLayout")
	topLayout.Padding = UDim.new(0, 10)
	topLayout.Parent = topStack

	local bossBtn = makeButton(topStack, "Auto Boss: OFF", 40)
	local tBtn = makeButton(topStack, "Auto T: OFF", 40)

	-------------------------------------------------
	-- 2 Columns
	-------------------------------------------------
	local columns = Instance.new("Frame")
	columns.Size = UDim2.new(1, 0, 1, -102)
	columns.Position = UDim2.new(0, 0, 0, 102)
	columns.BackgroundTransparency = 1
	columns.Parent = contentHolder

	local leftCol = Instance.new("Frame")
	leftCol.Size = UDim2.new(0.5, -6, 1, 0)
	leftCol.BackgroundTransparency = 1
	leftCol.Parent = columns

	local rightCol = Instance.new("Frame")
	rightCol.Size = UDim2.new(0.5, -6, 1, 0)
	rightCol.Position = UDim2.new(0.5, 6, 0, 0)
	rightCol.BackgroundTransparency = 1
	rightCol.Parent = columns

	local leftScroll = Instance.new("ScrollingFrame")
	leftScroll.Size = UDim2.new(1, 0, 1, 0)
	leftScroll.BackgroundTransparency = 1
	leftScroll.BorderSizePixel = 0
	leftScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	leftScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	leftScroll.ScrollBarThickness = 4
	leftScroll.Parent = leftCol

	local rightScroll = Instance.new("ScrollingFrame")
	rightScroll.Size = UDim2.new(1, 0, 1, 0)
	rightScroll.BackgroundTransparency = 1
	rightScroll.BorderSizePixel = 0
	rightScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rightScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	rightScroll.ScrollBarThickness = 4
	rightScroll.Parent = rightCol

	local leftLayout = Instance.new("UIListLayout")
	leftLayout.Padding = UDim.new(0, 10)
	leftLayout.Parent = leftScroll

	local rightLayout = Instance.new("UIListLayout")
	rightLayout.Padding = UDim.new(0, 10)
	rightLayout.Parent = rightScroll

	-------------------------------------------------
	-- Left: Auto Miner
	-------------------------------------------------
	local minerSection = createSection(leftScroll, "Auto Miner")
	local minerBtn = makeButton(minerSection, "Auto Miner: OFF", 40)
	local defendBtn = makeButton(minerSection, "Auto Defend: OFF", 40)
	local clearBtn = makeButton(minerSection, "Auto Clear Trash: OFF", 40)
	local locationSelect = createMultiSelect(minerSection, locationNames, state.selectedLocations, "Select locations...", 200)
	local mineralSelect = createMultiSelect(minerSection, mineralNames, state.selectedMinerals, "Select minerals...", 220)
	local oreSelect = createMultiSelect(minerSection, oreNames, state.selectedOres, "Select ores...", 220)

	-------------------------------------------------
	-- Right: Auto Monster + Potions
	-------------------------------------------------
	local monsterSection = createSection(rightScroll, "Auto Monster")
	local monsterFarmBtn = makeButton(monsterSection, "Auto Monster Farm: OFF", 40)
	local monsterSelect = createMultiSelect(monsterSection, monsterNames, state.selectedMonsters, "Select monsters...", 240)

	local potionSection = createSection(rightScroll, "Potions & Utility")
	local luckAutoBtn = makeButton(potionSection, "Auto Luck Potion: OFF", 40)
	local luckBuyBtn = makeButton(potionSection, "Auto Buy Luck: OFF", 40)
	local minerPotionBtn = makeButton(potionSection, "Auto Miner Potion: OFF", 40)
	local minerBuyBtn = makeButton(potionSection, "Auto Buy Miner: OFF", 40)
	local mazeBtn = makeButton(potionSection, "Go Maze Merchant", 40)

	-------------------------------------------------
	-- Refresh
	-------------------------------------------------
	local refreshButtons

	refreshButtons = function()
		local minerText = state.autoMiner and "ON" or "OFF"
		local defendText = state.autoDefend and "ON" or "OFF"
		local monsterFarmText = state.autoMonsterFarm and "ON" or "OFF"

		if state.isClearing then
			minerText = "WAIT"
			defendText = "WAIT"
		end

		local function applyToggle(btn, enabled, text, onColor, offColor)
			btn.Text = text
			btn.BackgroundColor3 = enabled
				and (onColor or Color3.fromRGB(45, 132, 82))
				or (offColor or Color3.fromRGB(52, 58, 72))
		end

		applyToggle(bossBtn, state.autoBoss, "Auto Boss: " .. (state.autoBoss and "ON" or "OFF"), Color3.fromRGB(160, 67, 67))
		applyToggle(tBtn, state.autoPressT, "Auto T: " .. (state.autoPressT and "ON" or "OFF"), Color3.fromRGB(66, 110, 176))
		applyToggle(minerBtn, state.autoMiner, "Auto Miner: " .. minerText)
		applyToggle(defendBtn, state.autoDefend, "Auto Defend: " .. defendText)
		applyToggle(clearBtn, state.autoClearTrash, "Auto Clear Trash: " .. (state.autoClearTrash and "ON" or "OFF"), Color3.fromRGB(150, 117, 50))
		applyToggle(monsterFarmBtn, state.autoMonsterFarm, "Auto Monster Farm: " .. monsterFarmText, Color3.fromRGB(92, 76, 173))
		applyToggle(luckAutoBtn, state.autoUseLuckPotion, "Auto Luck Potion: " .. (state.autoUseLuckPotion and "ON" or "OFF"))
		applyToggle(luckBuyBtn, state.autoBuyLuckPotion, "Auto Buy Luck: " .. (state.autoBuyLuckPotion and "ON" or "OFF"))
		applyToggle(minerPotionBtn, state.autoUseMinerPotion, "Auto Miner Potion: " .. (state.autoUseMinerPotion and "ON" or "OFF"))
		applyToggle(minerBuyBtn, state.autoBuyMinerPotion, "Auto Buy Miner: " .. (state.autoBuyMinerPotion and "ON" or "OFF"))

		if state.autoNpcBusy then
			mazeBtn.Text = "Go Maze Merchant: MOVING"
			mazeBtn.BackgroundColor3 = Color3.fromRGB(220, 140, 40)
		else
			mazeBtn.Text = "Go Maze Merchant"
			mazeBtn.BackgroundColor3 = Color3.fromRGB(52, 58, 72)
		end

		worldValue.Text = detectCurrentWorldName()

		if state.autoBoss and state.bossInProgress then
			statusValue.Text = "Boss in progress..."
			statusValue.TextColor3 = Color3.fromRGB(255, 128, 128)
		elseif state.autoBoss and state.bossPriorityActive then
			statusValue.Text = "Waiting / switching to boss..."
			statusValue.TextColor3 = Color3.fromRGB(255, 180, 105)
		elseif state.autoNpcBusy then
			statusValue.Text = "Moving to Maze Merchant..."
			statusValue.TextColor3 = Color3.fromRGB(255, 214, 140)
		elseif state.isClearing then
			statusValue.Text = state.clearStatusText ~= "" and state.clearStatusText or "Clearing..."
			statusValue.TextColor3 = Color3.fromRGB(255, 214, 140)
		elseif state.autoMonsterFarm then
			statusValue.Text = "Monster farming"
			statusValue.TextColor3 = Color3.fromRGB(172, 204, 255)
		elseif state.autoMiner then
			statusValue.Text = "Mining"
			statusValue.TextColor3 = Color3.fromRGB(172, 255, 194)
		else
			statusValue.Text = "Idle"
			statusValue.TextColor3 = Color3.fromRGB(225, 230, 240)
		end
	end

	-------------------------------------------------
	-- Actions
	-------------------------------------------------
	bossBtn.MouseButton1Click:Connect(function()
		state.autoBoss = not state.autoBoss
		refreshButtons()
	end)

	tBtn.MouseButton1Click:Connect(function()
		state.autoPressT = not state.autoPressT
		refreshButtons()
	end)

	minerBtn.MouseButton1Click:Connect(function()
		state.autoMiner = not state.autoMiner
		if state.autoMiner then
			state.autoMonsterFarm = false
		end
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

	mazeBtn.MouseButton1Click:Connect(function()
		if state.autoNpcBusy then
			return
		end

		if state.goToMazeMerchant then
			state.goToMazeMerchant()
		else
			warn("state.goToMazeMerchant not found")
		end

		refreshButtons()
	end)

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

	-------------------------------------------------
	-- Collapse / Maximize
	-------------------------------------------------
	local function closeAllDropdowns()
		locationSelect.close()
		mineralSelect.close()
		oreSelect.close()
		monsterSelect.close()
	end

	-- local function setCollapsed(collapsed)
	-- 	isCollapsed = collapsed
	-- 	closeAllDropdowns()

	-- 	if collapsed then
	-- 		contentHolder.Visible = false
	-- 		frame:TweenSize(collapsedSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
	-- 		collapseBtn.Text = "+"
	-- 	else
	-- 		contentHolder.Visible = true
	-- 		frame:TweenSize(isMaximized and maximizedSize or expandedSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
	-- 		collapseBtn.Text = "—"
	-- 	end
	-- end

	local normalAnchor = Vector2.new(0.5, 0.5)
	local collapsedAnchor = Vector2.new(0, 0.5)

	local function setCollapsed(collapsed)
		isCollapsed = collapsed
		closeAllDropdowns()

		if collapsed then
			if not isMaximized then
				storedPosition = frame.Position
				storedSize = frame.Size
			end

			contentHolder.Visible = false

			frame.AnchorPoint = collapsedAnchor
			frame:TweenPosition(
				UDim2.new(0, 12, 0.5, 0),
				Enum.EasingDirection.Out,
				Enum.EasingStyle.Quad,
				0.15,
				true
			)
			frame:TweenSize(
				collapsedSize,
				Enum.EasingDirection.Out,
				Enum.EasingStyle.Quad,
				0.15,
				true
			)

			collapseBtn.Text = "+"
		else
			contentHolder.Visible = true

			frame.AnchorPoint = normalAnchor

			if isMaximized then
				frame:TweenPosition(
					UDim2.new(0.5, 0, 0.5, 0),
					Enum.EasingDirection.Out,
					Enum.EasingStyle.Quad,
					0.15,
					true
				)
				frame:TweenSize(
					maximizedSize,
					Enum.EasingDirection.Out,
					Enum.EasingStyle.Quad,
					0.15,
					true
				)
			else
				frame:TweenPosition(
					storedPosition,
					Enum.EasingDirection.Out,
					Enum.EasingStyle.Quad,
					0.15,
					true
				)
				frame:TweenSize(
					expandedSize,
					Enum.EasingDirection.Out,
					Enum.EasingStyle.Quad,
					0.15,
					true
				)
			end

			collapseBtn.Text = "_"
		end
	end

	-- local function setMaximized(maximized)
	-- 	isMaximized = maximized
	-- 	closeAllDropdowns()

	-- 	if maximized then
	-- 		storedPosition = frame.Position
	-- 		storedSize = frame.Size
	-- 		frame:TweenPosition(UDim2.new(0.5, 0, 0.5, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
	-- 		frame:TweenSize(maximizedSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
	-- 		maxBtn.Text = "❐"
	-- 	else
	-- 		frame:TweenPosition(storedPosition, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
	-- 		frame:TweenSize(isCollapsed and collapsedSize or expandedSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
	-- 		maxBtn.Text = "▢"
	-- 	end
	-- end

	local function setMaximized(maximized)
		isMaximized = maximized
		closeAllDropdowns()

		if maximized then
			if not isCollapsed then
				storedPosition = frame.Position
				storedSize = frame.Size
			end

			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame:TweenPosition(
				UDim2.new(0.5, 0, 0.5, 0),
				Enum.EasingDirection.Out,
				Enum.EasingStyle.Quad,
				0.15,
				true
			)
			frame:TweenSize(
				maximizedSize,
				Enum.EasingDirection.Out,
				Enum.EasingStyle.Quad,
				0.15,
				true
			)

			maxBtn.Text = "[]"
		else
			if isCollapsed then
				frame.AnchorPoint = Vector2.new(0, 0.5)
				frame:TweenPosition(
					UDim2.new(0, 12, 0.5, 0),
					Enum.EasingDirection.Out,
					Enum.EasingStyle.Quad,
					0.15,
					true
				)
				frame:TweenSize(
					collapsedSize,
					Enum.EasingDirection.Out,
					Enum.EasingStyle.Quad,
					0.15,
					true
				)
			else
				frame.AnchorPoint = Vector2.new(0.5, 0.5)
				frame:TweenPosition(
					storedPosition,
					Enum.EasingDirection.Out,
					Enum.EasingStyle.Quad,
					0.15,
					true
				)
				frame:TweenSize(
					expandedSize,
					Enum.EasingDirection.Out,
					Enum.EasingStyle.Quad,
					0.15,
					true
				)
			end

			maxBtn.Text = "□"
		end
	end

	collapseBtn.MouseButton1Click:Connect(function()
		setCollapsed(not isCollapsed)
	end)

	maxBtn.MouseButton1Click:Connect(function()
		setMaximized(not isMaximized)
	end)

	-------------------------------------------------
	-- Dragging
	-------------------------------------------------
	local dragToggle = false
	local dragInput = nil
	local dragStart = nil
	local startPos = nil

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
		if isMaximized or isCollapsed then
			return
		end

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

	-------------------------------------------------
	-- Start
	-------------------------------------------------
	refreshButtons()
	setCollapsed(false)

	task.spawn(function()
		while getgenv().RobloxUIRunning and screenGui.Parent do
			refreshButtons()
			task.wait(0.3)
		end
	end)

	return screenGui
end

return UI