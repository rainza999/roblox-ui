local PressT = {}
local started = false

function PressT.tap()
	print("Pressed T")
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