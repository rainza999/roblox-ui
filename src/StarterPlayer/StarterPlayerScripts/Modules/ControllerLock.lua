local ControllerLock = {}

function ControllerLock.tryAcquire(State, owner, reason)
	if State.activeController == nil then
		State.activeController = owner
		State.activeReason = reason
		return true
	end

	if State.activeController == owner then
		State.activeReason = reason
		return true
	end

	return false
end

function ControllerLock.release(State, owner)
	if State.activeController == owner then
		State.activeController = nil
		State.activeReason = nil
		return true
	end
	return false
end

function ControllerLock.isOwnedByOther(State, owner)
	return State.activeController ~= nil and State.activeController ~= owner
end

return ControllerLock