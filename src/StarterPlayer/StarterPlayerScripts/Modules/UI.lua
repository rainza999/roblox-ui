local Players = game:GetService("Players")

local UI = {}

function UI.create(state)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local oldGui = playerGui:FindFirstChild("ControlPanel V.2")
	if oldGui then
		oldGui:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ControlPanel V.2.1."
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 260, 0, 180)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -40, 0, 40)
	title.Position = UDim2.new(0, 10, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "Control Panel V.2.2"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 40, 0, 40)
	closeBtn.Position = UDim2.new(1, -40, 0, 0)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	closeBtn.Parent = frame

	closeBtn.MouseButton1Click:Connect(function()

		getgenv().RobloxUIRunning = false

		screenGui:Destroy()

	end)

	local function makeButton(text, y)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -20, 0, 40)
		btn.Position = UDim2.new(0, 10, 0, y)
		btn.Text = text
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		btn.Parent = frame
		return btn
	end

	local bossBtn = makeButton("Auto Boss: OFF", 50)
	local tBtn = makeButton("Auto T: OFF", 100)

	local function refreshButtons()
		bossBtn.Text = "Auto Boss: " .. (state.autoBoss and "ON" or "OFF")
		bossBtn.BackgroundColor3 = state.autoBoss
			and Color3.fromRGB(40, 140, 70)
			or Color3.fromRGB(60, 60, 60)

		tBtn.Text = "Auto T: " .. (state.autoPressT and "ON" or "OFF")
		tBtn.BackgroundColor3 = state.autoPressT
			and Color3.fromRGB(40, 140, 70)
			or Color3.fromRGB(60, 60, 60)
	end

	bossBtn.MouseButton1Click:Connect(function()
		state.autoBoss = not state.autoBoss
		refreshButtons()
	end)

	tBtn.MouseButton1Click:Connect(function()
		state.autoPressT = not state.autoPressT
		refreshButtons()
	end)

	refreshButtons()

	return screenGui
end

return UI