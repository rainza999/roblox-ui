local PressT = {}

function PressT.tap()
	local VirtualInputManager = game:GetService("VirtualInputManager")

	print("Pressed T")

	-- กด T
	VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.T, false, game)
	task.wait(0.1)
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.T, false, game)
end

function PressT.startAntiAFK()
	task.spawn(function()
		while getgenv().RobloxUIRunning do
			print("START... PRESS T wait")
			task.wait(60) -- 10 นาที (600 วินาที)

			print("Anti AFK Trigger")

			PressT.tap()
			task.wait(0.5)
			PressT.tap()
		end
	end)
end

return PressT