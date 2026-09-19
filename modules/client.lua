local DoorRecs = {}       -- door index → w.prompt.at record
local SyncedDoors = {}
local PromptKey = Config.KeyPress:upper()
local Busy = false          -- a toggle (animation + server round trip) is in progress

-- RDR3 ped bone the key prop hangs from (resolved by the library through GetEntityBoneIndexByName)
local KEY_BONE = 'SKEL_R_Finger12'

-- RDR3 door system natives (OBJECT namespace, known by hash only)
local function AddDoorToSystemNew(DOOR, B1, B2, B3, THREADID, INT, B6) return Citizen.InvokeNative(0xD99229FE93B46286, DOOR, B1, B2, B3, THREADID, INT, B6) end
local function DoorSystemSetDoorState(DOOR, STATE) return Citizen.InvokeNative(0x6BAB9442830C7F53, DOOR, STATE) end
local function DoorSystemForceShut(DOOR, BOOL) return Citizen.InvokeNative(0x276AAF0F1C7F2494, DOOR, BOOL) end

-- RDR3 eDoorState: -1 invalid, 0 unlocked, 1 locked (unbreakable), 2 locked (breakable),
-- 3 hold open (positive), 4 hold open (negative).
-- Registration first pushes state 4 (the reset the RDR3 door sequence starts from) and then the real lock state.
local STATE_RESET = 4
local function LockState(locked) return locked and 1 or 0 end

local wc = {}

-- Prompt title / label of a door follow its lock state (and the language) --
local function ApplyPromptLabels(DOOR)
	local rec = DoorRecs[DOOR]
	if not rec then return end
	local locked = SyncedDoors[DOOR] and SyncedDoors[DOOR].locked
	rec.setTitle(locale(locked and 'prompt.title_locked' or 'prompt.title_unlocked'))
	rec.setLabel(PromptKey, locale(locked and 'prompt.unlock' or 'prompt.lock'))
end

-- Live language switch: the library already reloaded the dictionary, relabel every door prompt --
function wc.RelabelPrompts()
	for DOOR in pairs(DoorRecs) do ApplyPromptLabels(DOOR) end
end

-- Create All Doors --
function wc.CreateDoors()
    -- Drop any prompts from a previous run (onResourceStart and OnPlayerLoaded both call this)
    wc.RemovePoints()
    -- w_lib 4.0: triggerServer returns false when the callback is missing or times out
    SyncedDoors = w.callback.triggerServer('w_doorlock:server:SyncDoors') or {}
    for x = 1, #SyncedDoors do
        local isDouble = SyncedDoors[x].double
        wc.DoorPrompt(x)
        if isDouble then
            for q = 1, #isDouble do
                local doorInfo = isDouble[q]
                AddDoorToSystemNew(doorInfo.doorid, 1, 1, 0, 0, 0, 0)
                DoorSystemSetDoorState(doorInfo.doorid, STATE_RESET)
                DoorSystemSetDoorState(doorInfo.doorid, LockState(SyncedDoors[x].locked))
                DoorSystemSetAutomaticRate(doorInfo.doorid, 10.0)
                if SyncedDoors[x].locked and not IsDoorClosed(doorInfo.doorid) then DoorSystemForceShut(doorInfo.doorid, false) end
            end
        else
            AddDoorToSystemNew(SyncedDoors[x].doorid, 1, 1, 0, 0, 0, 0)
		    DoorSystemSetDoorState(SyncedDoors[x].doorid, STATE_RESET)
		    DoorSystemSetDoorState(SyncedDoors[x].doorid, LockState(SyncedDoors[x].locked))
			DoorSystemSetAutomaticRate(SyncedDoors[x].doorid, 10.0)
			if SyncedDoors[x].locked and not IsDoorClosed(SyncedDoors[x].doorid) then DoorSystemForceShut(SyncedDoors[x].doorid, false) end
        end
    end

	for _, x in pairs(Doors.UnlockedDoors) do
		AddDoorToSystemNew(x, 1, 1, 0, 0, 0, 0)
		DoorSystemSetDoorState(x, STATE_RESET)
		DoorSystemSetDoorState(x, LockState(false))
	end
end

-- Sync Door State --
function wc.SyncDoor(doorID, state)
    -- Nothing to sync before CreateDoors ran (or when the initial sync failed and left the list empty)
    if not SyncedDoors[doorID] then return end
    SyncedDoors[doorID].locked = state
    if SyncedDoors[doorID].double then
        for x = 1, 2 do
            local door = SyncedDoors[doorID].double[x].doorid
            DoorSystemSetDoorState(door, LockState(state))
			if state and not IsDoorClosed(door) then DoorSystemForceShut(door, false) end
        end
    else
        DoorSystemSetDoorState(SyncedDoors[doorID].doorid, LockState(state))
		if state and not IsDoorClosed(SyncedDoors[doorID].doorid) then DoorSystemForceShut(SyncedDoors[doorID].doorid, false) end
    end
	-- The prompt of this door follows the new state (relabelled even while hidden)
	ApplyPromptLabels(doorID)
end

-- Create Door Prompt (library proximity prompt: shown while the player stands within the door's distance) --
function wc.DoorPrompt(DOOR)
	local maxDist = SyncedDoors[DOOR].distance
	local isDouble = SyncedDoors[DOOR].double
	local coords
	if isDouble then
		coords = ((isDouble[1].objCoords + isDouble[2].objCoords)/2)
	else
		coords = SyncedDoors[DOOR].objCoords
	end

	local locked = SyncedDoors[DOOR].locked
	local rec
	rec = w.prompt.at({
		coords = coords,
		distance = maxDist,
		title = locale(locked and 'prompt.title_locked' or 'prompt.title_unlocked'),
		position = Config.PromptPosition,
		prompts = {
			{
				key = PromptKey,
				label = locale(locked and 'prompt.unlock' or 'prompt.lock'),
				hold = Config.PromptHold,
				onComplete = function()
					if not SyncedDoors[DOOR] then return end
					wc.ToggleDoor(DOOR, not SyncedDoors[DOOR].locked)
				end,
			},
		},
		-- One door prompt at a time (the closest door wins where ranges overlap); none while a
		-- toggle or another progress bar (eating, crafting...) runs
		canInteract = function()
			return not Busy and not w.progressActive() and w.points.getClosestPoint() == rec.point
		end,
	})
	DoorRecs[DOOR] = rec
end

-- Remove All Door Prompts (Cleanup) --
function wc.RemovePoints()
	for DOOR, rec in pairs(DoorRecs) do
		rec.remove()
		DoorRecs[DOOR] = nil
	end
end

-- Anim & Toggle State --
function wc.ToggleDoor(DOOR, STATE)
	-- One toggle at a time; nothing while another progress bar (eating, crafting...) runs
	-- (Busy also hides the door prompt through canInteract until the toggle is over)
	if Busy or w.progressActive() then return end
	Busy = true

	-- An interrupted animation (ragdoll, death...) does not touch the door
	if wc.Anim(STATE) then
		-- 1000 ms throttle on the wire as well (returns nothing when throttled)
		local Toggle = w.callback.await('w_doorlock:server:UpdateState', 1000, DOOR, STATE)
		if Toggle == false then
			w.notify({ description = locale('notify.no_access'), type = 'error', isRTL = w.getLocaleKey() == 'ar' })
		end
	end
	Busy = false
end

-- Lock / Unlock Anim (library progress bar: animation + key prop in hand); true when it completed --
function wc.Anim(STATE)
	return w.progressBar({
		duration = 2500,
		label = locale(STATE and 'progress.lock' or 'progress.unlock'),
		canCancel = false,
		anim = { dict = 'script_common@jail_cell@unlock@key', clip = 'action', blendIn = 8.0, blendOut = -8.0, duration = 2500, flag = 31 },
		prop = { model = 'P_KEY02X', bone = KEY_BONE, pos = vec3(0.02, 0.0120, -0.00850), rot = vec3(0.024, -160.0, 200.0), rotOrder = 1 },
	})
end

return wc
