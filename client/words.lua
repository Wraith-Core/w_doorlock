-- ════════════════════════════════════════════════════════════════════════════
-- w_doorlock · client/words.lua
-- A door in words (the notebook board, 2026-11-12): the board and the pins never show a raw door id
-- (valentine_sheriff_front) or a coordinate.
--
--   WDoor.label(name)        a staff-typed name as it is; a system id read in words:
--                            valentine_sheriff_front -> «مكتب الشريف · الباب الأمامي»
--                            (the town is left out: the place line under it says it)
--   WDoor.where(coords)      { text = 'فالنتاين · 12 م منك', meters = 12 } through w_lib's lib.place
--                            (4.5.0); the region's name alone on an older w_lib
-- The words are locales/<lang>.json "word"; a part with no word stays as it is.
-- ════════════════════════════════════════════════════════════════════════════
WDoor = WDoor or {}

-- the parts of a system id that name a town (left out of the label: the place line says the town)
local TOWNS <const> = {
    valentine = true, val = true, rhodes = true, blackwater = true, bw = true, strawberry = true,
    saintdenis = true, sd = true, armadillo = true, tumbleweed = true, annesburg = true, vanhorn = true,
    emerald = true, lagras = true, wapiti = true, manzanita = true, colter = true,
}

-- two parts read as one word (saint_denis, cell_area ...)
local PAIRS <const> = { saint_denis = 'saintdenis', cell_area = 'cellarea', van_horn = 'vanhorn', back_room = 'backroom' }

local function word(part)
    local key = 'word.' .. part
    local text = locale(key)
    if type(text) ~= 'string' or text == '' or text == key then return nil end
    return text
end

---@param name string|nil the door's saved name
---@return string
function WDoor.label(name)
    name = tostring(name or '')
    if name == '' or not name:match('^[%w_%-]+$') or not name:find('_') then
        return name
    end
    local lower = name:lower()
    for pair, one in pairs(PAIRS) do lower = lower:gsub(pair, one) end

    local out, known = {}, 0
    for part in lower:gmatch('[^_%-]+') do
        if part:match('^%d+$') then
            if #out > 0 then out[#out] = out[#out] .. ' ' .. part else out[1] = part end
        elseif not TOWNS[part] then
            local text = word(part)
            if text then known = known + 1 end
            out[#out + 1] = text or part
        else
            known = known + 1
        end
    end
    if known == 0 or #out == 0 then return name end
    return table.concat(out, ' · ')
end

local function hasPlace()
    local ok, place = pcall(function() return w.place end)
    return ok and type(place) == 'table' and type(place.describe) == 'function'
end

---@param coords table|vector3|nil
---@return { text: string, meters: number|nil }
function WDoor.where(coords)
    if not coords then return { text = '' } end
    if hasPlace() then
        local ok, spot = pcall(w.place.describe, vector3(coords.x, coords.y, coords.z or 0.0))
        if ok and type(spot) == 'table' and type(spot.text) == 'string' then
            return { text = spot.text, meters = tonumber(spot.meters) }
        end
    end
    local ped = PlayerPedId()
    local at = GetEntityCoords(ped)
    local meters = #(at - vector3(coords.x, coords.y, coords.z or at.z))
    return { text = WDoor.zoneOf(coords), meters = meters }
end
