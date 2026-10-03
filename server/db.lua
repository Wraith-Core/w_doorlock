-- ════════════════════════════════════════════════════════════════════════════
-- w_doorlock · server/db.lua
-- The doors live in one table (id, name, data as JSON) through w_lib's database bridge
-- (exports.w_lib:Db*): no driver of our own, no oxmysql line in the manifest.
--
-- At start, in order:
--   1. CREATE TABLE IF NOT EXISTS w_doorlock - the columns of ox_doorlock's own table
--   2. an ox_doorlock table left by the script this one replaces is copied in, ids kept
--   3. the doors the old w_doorlock kept in a Lua file (data/legacy.lua) are added
-- Steps 2 and 3 run once: the resource KVP remembers them, so a door the staff deleted on the
-- board never comes back on the next restart.
--
--   Db.init()                  -> true | false      (prints why on failure)
--   Db.all()                   -> { { id, name, data }, ... }
--   Db.insert(name, json)      -> id | nil
--   Db.update(id, name, json)  -> true | false
--   Db.delete(id)              -> true | false
--
-- ★ Every call awaits: from a thread, an event or a callback handler only.
-- ════════════════════════════════════════════════════════════════════════════
Db = {}

local TABLE = 'w_doorlock'
local LEGACY_TABLE = 'ox_doorlock'

local function lib() return exports.w_lib end

local function failed(what, err)
    w.print.error('%s: %s', what, type(err) == 'table' and (err.message or err.code) or tostring(err))
end

function Db.all()
    local rows, err = lib():DbQuery(('SELECT `id`, `name`, `data` FROM `%s` ORDER BY `id`'):format(TABLE))
    if err then failed('reading the doors', err) return {} end
    return rows or {}
end

function Db.insert(name, data)
    local id, err = lib():DbInsert(('INSERT INTO `%s` (`name`, `data`) VALUES (?, ?)'):format(TABLE), { name, data })
    if err then failed('adding a door', err) return nil end
    return tonumber(id)
end

function Db.update(id, name, data)
    local _, err = lib():DbUpdate(('UPDATE `%s` SET `name` = ?, `data` = ? WHERE `id` = ?'):format(TABLE), { name, data, id })
    if err then failed('saving door ' .. tostring(id), err) return false end
    return true
end

function Db.delete(id)
    local _, err = lib():DbUpdate(('DELETE FROM `%s` WHERE `id` = ?'):format(TABLE), { id })
    if err then failed('deleting door ' .. tostring(id), err) return false end
    return true
end

-- ════════════════════════════════════════════════════════════════════════════
-- The one-time steps
-- ════════════════════════════════════════════════════════════════════════════

local function once(key, fn)
    local flag = 'w_doorlock:' .. key
    if GetResourceKvpInt(flag) == 1 then return end
    if fn() then SetResourceKvpInt(flag, 1) end
end

--- ox_doorlock's table, when the server ran that script before: every row comes across with its id
local function fromOxDoorlock()
    local found, err = lib():DbScalar(
        'SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?',
        { LEGACY_TABLE })
    if err then failed('looking for ' .. LEGACY_TABLE, err) return false end
    if (tonumber(found) or 0) == 0 then return true end

    local mine = lib():DbScalar(('SELECT COUNT(*) FROM `%s`'):format(TABLE))
    if (tonumber(mine) or 0) > 0 then return true end   -- the board already has doors of its own

    local moved, moveErr = lib():DbUpdate(('INSERT INTO `%s` (`id`, `name`, `data`) SELECT `id`, LEFT(`name`, 100), `data` FROM `%s`')
        :format(TABLE, LEGACY_TABLE))
    if moveErr then failed('copying ' .. LEGACY_TABLE, moveErr) return false end
    w.print.info('%d door(s) copied from the %s table', tonumber(moved) or 0, LEGACY_TABLE)
    return true
end

--- The hashes a stored door already holds, so a legacy door is never added twice
local function knownHashes()
    local known = {}
    for _, row in ipairs(Db.all()) do
        local ok, data = pcall(json.decode, row.data)
        if ok and type(data) == 'table' then
            if data.hash then known[tonumber(data.hash) or 0] = true end
            for _, leaf in ipairs(type(data.doors) == 'table' and data.doors or {}) do
                if leaf.hash then known[tonumber(leaf.hash) or 0] = true end
            end
        end
    end
    return known
end

--- The doors of the old w_doorlock (shared/sh_doors.lua there), already in this script's shape
local function fromLegacyList()
    local ok, legacy = pcall(require, 'data.legacy')
    if not ok or type(legacy) ~= 'table' then
        w.print.warn('data/legacy.lua could not be read: %s', tostring(legacy))
        return true
    end

    local known = knownHashes()
    local added = 0
    for _, door in ipairs(legacy) do
        local hashes = {}
        if door.doors then
            hashes = { door.doors[1].hash, door.doors[2].hash }
        else
            hashes = { door.hash }
        end
        local fresh = true
        for _, hash in ipairs(hashes) do
            if known[hash] then fresh = false end
        end
        if fresh then
            local name = door.name
            door.name = nil
            if Db.insert(name, json.encode(door)) then
                added = added + 1
                for _, hash in ipairs(hashes) do known[hash] = true end
            else
                return false
            end
        end
    end
    if added > 0 then w.print.info('%d door(s) brought over from the old w_doorlock list', added) end
    return true
end

function Db.init()
    local ready, err = lib():DbReady(30000)
    if not ready then failed('the database is not available', err) return false end

    local _, createErr = lib():DbQuery(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(100) NOT NULL,
            `data` LONGTEXT NOT NULL,
            PRIMARY KEY (`id`)
        )
    ]]):format(TABLE))
    if createErr then failed('creating the ' .. TABLE .. ' table', createErr) return false end

    once('migrated:ox_doorlock', fromOxDoorlock)
    once('seeded:legacy', fromLegacyList)
    return true
end
