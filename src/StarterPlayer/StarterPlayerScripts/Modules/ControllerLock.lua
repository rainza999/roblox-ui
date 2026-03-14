local ControllerLock = {}

local PRIORITY = {
	PotionManager = 100,
	AutoBoss = 90,
	AutoMonster = 50,
	AutoMiner = 40,
}

local function ensure(State)
	State.activeController = State.activeController or nil
	State.activeReason = State.activeReason or nil
	State.activePriority = State.activePriority or 0
	State.controllerSince = State.controllerSince or 0
end

function ControllerLock.tryAcquire(State, owner, reason)
	ensure(State)

	local ownerPriority = PRIORITY[owner] or 0

	if State.activeController == nil then
		State.activeController = owner
		State.activeReason = reason or "unknown"
		State.activePriority = ownerPriority
		State.controllerSince = tick()
		return true
	end

	if State.activeController == owner then
		State.activeReason = reason or State.activeReason
		State.activePriority = ownerPriority
		return true
	end

	return false
end

function ControllerLock.trySteal(State, owner, reason)
	ensure(State)

	local ownerPriority = PRIORITY[owner] or 0
	local currentPriority = State.activePriority or 0

	if State.activeController == nil then
		State.activeController = owner
		State.activeReason = reason or "unknown"
		State.activePriority = ownerPriority
		State.controllerSince = tick()
		return true
	end

	if State.activeController == owner then
		State.activeReason = reason or State.activeReason
		State.activePriority = ownerPriority
		return true
	end

	if ownerPriority > currentPriority then
		State.activeController = owner
		State.activeReason = reason or "unknown"
		State.activePriority = ownerPriority
		State.controllerSince = tick()
		return true
	end

	return false
end

function ControllerLock.release(State, owner)
	ensure(State)

	if State.activeController == owner then
		State.activeController = nil
		State.activeReason = nil
		State.activePriority = 0
		State.controllerSince = 0
		return true
	end

	return false
end

function ControllerLock.isOwnedByOther(State, owner)
	ensure(State)
	return State.activeController ~= nil and State.activeController ~= owner
end

function ControllerLock.getOwner(State)
	ensure(State)
	return State.activeController, State.activeReason, State.activePriority
end

return ControllerLock