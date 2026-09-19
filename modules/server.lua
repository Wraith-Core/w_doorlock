local ws = {}

-- Check if Player is Authorized to Lock/Unlock Door --
function ws.IsAuthorized(src, DOORINFO)
	local Player = WCore.Functions.GetPlayer(src)
	local callback = false
	if not Player or not DOORINFO then return callback end

	local job = Player.PlayerData.job and Player.PlayerData.job.name
	local gang = Player.PlayerData.gang and Player.PlayerData.gang.name

	if DOORINFO.jobs then
		if type(DOORINFO.jobs) == 'table' then
			for _,x in pairs(DOORINFO.jobs) do
				if job == x then
					callback = true
					break
				end
			end
		elseif type(DOORINFO.jobs) == 'string' then
			if job == DOORINFO.jobs then
				callback = true
			end
		end
	end

	if DOORINFO.gangs then
		if type(DOORINFO.gangs) == 'table' then
			for _,x in pairs(DOORINFO.gangs) do
				if gang == x then
					callback = true
					break
				end
			end
		elseif type(DOORINFO.gangs) == 'string' then
			if gang == DOORINFO.gangs then
				callback = true
			end
		end
	end

	return callback
end

-- Update Door State --
function ws.UpdateState(src, ID, STATE)
	local Player = WCore.Functions.GetPlayer(src)
	local callback = false
	if not Player then return callback end
	if type(ID) ~= 'number' or not Doors.List[ID] then return callback end
	if type(STATE) ~= 'boolean' then return callback end
	if not ws.IsAuthorized(src, Doors.List[ID]) then return callback end

	local PlayerCoords = GetEntityCoords(GetPlayerPed(src))
    local DoorCoords

	if Doors.List[ID].double then
		DoorCoords = ((Doors.List[ID].double[1].objCoords + Doors.List[ID].double[2].objCoords)/2)
	else
		DoorCoords = Doors.List[ID].objCoords
	end

	local dist = #(DoorCoords - PlayerCoords)

    if dist <= Doors.List[ID].distance then
		TriggerClientEvent('w_doorlock:client:SyncDoorState', -1, ID, STATE)
		Doors.List[ID].locked = STATE
		callback = true

		w.print.debug('Door ID: '..ID..' | Locked: '..tostring(STATE))
	end
	return callback
end

return ws