local modules = script:WaitForChild("Modules")

local State = require(modules:WaitForChild("State"))
local UI = require(modules:WaitForChild("UI"))
local PressT = require(modules:WaitForChild("PressT"))
local AutoAttackBoss = require(modules:WaitForChild("AutoAttackBoss"))

print("Main started")

UI.create(State)

task.spawn(function()
	while true do
		if State.autoBoss then
			print("Calling AutoAttackBoss.run")
			local ok, err = pcall(function()
				AutoAttackBoss.run(State)
			end)
			if not ok then
				warn("AutoAttackBoss.run error:", err)
			end
		end

		if State.autoPressT then
			print("Calling PressT.run")
			local ok, err = pcall(function()
				PressT.run(State)
			end)
			if not ok then
				warn("PressT.run error:", err)
			end
		end

		task.wait(0.2)
	end
end)