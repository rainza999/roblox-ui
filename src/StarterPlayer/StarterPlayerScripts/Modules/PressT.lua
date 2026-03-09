local PressT = {}
local started = false

function PressT.tap()
	local VirtualInputManager = game:GetService("VirtualInputManager")

	print("Pressed TTTT")

	VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.T, false, game)
	task.wait(0.1)
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.T, false, game)
end

function PressT.start(State)
	if started then
		return
	end
	started = true

	task.spawn(function()
		while getgenv().RobloxUIRunning do
			task.wait(60)

			if State.autoPressT then
				print("Trigger PressT twice")
				PressT.tap()
				task.wait(0.5)
				PressT.tap()
			end
		end
	end)
end

return PressT