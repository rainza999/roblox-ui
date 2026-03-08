local Players = game:GetService("Players")

local UI = {}

function UI.create(state)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ControlPanel"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 260, 0, 180)
	frame.Position = UDim2.new(0, 20, 0.5, -90)
	frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	frame.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "Control Panel"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextSize = 20
	title.Parent = frame

	local function makeButton(text, y)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -20, 0, 40)
		btn.Position = UDim2.new(0, 10, 0, y)
		btn.Text = text
		btn.Parent = frame
		return btn
	end

	local bossBtn = makeButton("Auto Boss: OFF", 50)
	local tBtn = makeButton("Auto T: OFF", 100)

	bossBtn.MouseButton1Click:Connect(function()
		state.autoBoss = not state.autoBoss
		bossBtn.Text = "Auto Boss: " .. (state.autoBoss and "ON" or "OFF")
	end)

	tBtn.MouseButton1Click:Connect(function()
		state.autoPressT = not state.autoPressT
		tBtn.Text = "Auto T: " .. (state.autoPressT and "ON" or "OFF")
	end)

	return screenGui
end

return UI