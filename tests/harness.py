"""Server harness: the real w_doorlock server Lua (shared/config.lua, server/bridge.lua, server/main.lua,
server/admin.lua) in Lua 5.4 through lupa. What a RedM server provides is simulated: the door table (server/db.lua
is replaced by a Lua table), w_lib's framework (players with a character id and a job), its permission node, the
players' places, and w_store's three exports (GetRole / GetStore / GetStores, answered from STORES the way
w_store answers them - tests/test_door_role.py in w_store pins that). No database, no network.

  py -3 -I -m unittest discover -s tests
"""
import os

from lupa import lua54

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSON_LUA = r"F:/Server RedM/Wraith Core/fxserver/citizen/scripting/lua/json.lua"
FILES = ['shared/config.lua', 'server/bridge.lua', 'server/main.lua', 'server/admin.lua']

SIM = r'''
-- ── time, threads (run at once: nothing here waits on anything) ─────────────────
CLOCK = 100000
function GetGameTimer() return CLOCK end
function CreateThread(fn) local co = coroutine.create(fn) local ok, err = coroutine.resume(co) if not ok then error(err) end end
Citizen = { CreateThread = CreateThread }
function Wait() end
TIMERS = {}
function SetTimeout(ms, fn) TIMERS[#TIMERS + 1] = { ms = ms, fn = fn } end
function FIRE_TIMERS() local list = TIMERS TIMERS = {} for _, t in ipairs(list) do t.fn() end end

-- ── natives ───────────────────────────────────────────────────────────────────
local vmeta = {}
vmeta.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
vmeta.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, vmeta) end
STATES = { w_lib = 'started', w_store = 'started' }
function GetResourceState(n) return STATES[n] or 'missing' end
function GetInvokingResource() return INVOKER end
POS = {}
function GetPlayerPed(src) return POS[tonumber(src)] and tonumber(src) or 0 end
function GetEntityCoords(ped) return POS[ped] end
function GetPlayerName(src) return 'player' .. tostring(src) end
function IsPlayerAceAllowed() return false end
CLIENT = {}
function TriggerClientEvent(name, target, ...) CLIENT[#CLIENT + 1] = { name = name, target = target, args = table.pack(...) } end
EVENTS = {}
function TriggerEvent(name, ...) EVENTS[#EVENTS + 1] = { name = name, args = table.pack(...) } end
function AddEventHandler() end
function RegisterNetEvent() end
PRINTED = {}
function print(...) local t = {} for i = 1, select('#', ...) do t[#t + 1] = tostring(select(i, ...)) end PRINTED[#PRINTED + 1] = table.concat(t, ' ') end
local kvp = {}
function GetResourceKvpInt(k) return kvp[k] or 0 end
function SetResourceKvpInt(k, v) kvp[k] = v end

-- ── w_lib ─────────────────────────────────────────────────────────────────────
function locale(key) return key end
CALLBACKS = {}
USERS = {}      -- [src] = { cid = '12', job = 'police', grade = 0 }
STAFF = {}      -- [src] = true: passes w_doorlock.admin
local function userOf(src)
  local u = USERS[tonumber(src)]
  if not u then return nil end
  return {
    getIdentifiers = function() return { charid = u.cid } end,
    getJob = function() return u.job end,
    getJobGrade = function() return u.grade or 0 end,
  }
end
w = {
  print = {
    info = function(f, ...) PRINTED[#PRINTED + 1] = string.format(f, ...) end,
    warn = function(f, ...) PRINTED[#PRINTED + 1] = 'WARN ' .. string.format(f, ...) end,
    error = function(f, ...) PRINTED[#PRINTED + 1] = 'ERROR ' .. string.format(f, ...) end,
  },
  callback = { register = function(name, fn) CALLBACKS[name] = fn end },
  citizen = { normalize = function(t) return t end, idOf = function() return nil end },
  framework = { getUser = function(_, src) return userOf(src) end },
  addCommand = function() end,
}
function CALL(name, ...) return CALLBACKS[name](...) end

-- ── w_store, as its exports answer (owner / staff by character id; nil for a government store,
--    central bank custody and a pending debt) ─────────────────────────────────────────────────
STORES = {}     -- [id] = { name, owner = cid|nil, ownerName, staff = { [cid] = true }, at = {x,y,z}, enabled = true }
STORE_THROWS = false
local store = {
  GetRole = function(_, src, id)
    if STORE_THROWS then error('w_store broke') end
    local s = STORES[tonumber(id)]
    if not s then return nil end
    if not s.owner or s.owner:sub(1, 7) == 'escrow:' or s.debtPending then return nil, {} end
    local u = USERS[tonumber(src)]
    if not u then return nil, {} end
    if s.owner == u.cid then return 'owner', {} end
    if s.staff and s.staff[u.cid] then return 'employee', {} end
    return nil, {}
  end,
  GetStore = function(_, id)
    if STORE_THROWS then error('w_store broke') end
    local s = STORES[tonumber(id)]
    return s and { id = tonumber(id), name = s.name } or nil
  end,
  GetStores = function()
    local out = {}
    for id, s in pairs(STORES) do
      if s.enabled ~= false then
        out[#out + 1] = { id = id, name = s.name, ownerName = s.ownerName, cashier = s.at and { x = s.at[1], y = s.at[2], z = s.at[3], model = 'm' } or nil }
      end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
  end,
}
EXPORTED = {}
exports = setmetatable({
  w_lib = { HasPermissionNode = function(_, src) return STAFF[tonumber(src)] == true end,
            InvGetItemCount = function() return 0 end, InvName = function() return nil end, InvItems = function() return nil end },
  w_store = store,
}, { __call = function(_, name, fn) EXPORTED[name] = fn end })

-- ── the door table (server/db.lua's interface) ─────────────────────────────────
ROWS, NEXT_ID = {}, 1
Db = {
  init = function() return true end,
  all = function() local out = {} for id, r in pairs(ROWS) do out[#out + 1] = { id = id, name = r.name, data = r.data } end table.sort(out, function(a, b) return a.id < b.id end) return out end,
  insert = function(name, data) local id = NEXT_ID NEXT_ID = NEXT_ID + 1 ROWS[id] = { name = name, data = data } return id end,
  update = function(id, name, data) ROWS[id] = { name = name, data = data } return true end,
  delete = function(id) ROWS[id] = nil return true end,
}
'''


class Server:
    """One fresh server per test. `doors` are rows put in the table before the resource starts."""

    def __init__(self, doors=None):
        self.L = lua54.LuaRuntime(unpack_returned_tuples=True)
        with open(JSON_LUA, encoding='utf-8') as f:
            self.L.execute(f.read())
        self.L.execute(SIM)
        for door_id, data in (doors or {}).items():
            self.L.globals().Db.insert(data.get('name', 'door%d' % door_id), self.L.globals().json.encode(self.to_lua(data)))
        for rel in FILES:
            with open(os.path.join(ROOT, rel), encoding='utf-8') as f:
                self.L.execute(f.read())

    # ── Lua helpers ──
    def run(self, code):
        return self.L.execute(code)

    def eval(self, code):
        return self.L.eval(code)

    def to_lua(self, v):
        if isinstance(v, dict):
            t = self.L.table()
            for k, x in v.items():
                t[k] = self.to_lua(x)
            return t
        if isinstance(v, (list, tuple)):
            t = self.L.table()
            for i, x in enumerate(v):
                t[i + 1] = self.to_lua(x)
            return t
        return v

    def py(self, v):
        if isinstance(v, tuple):
            return tuple(self.py(x) for x in v)
        if lua54.lua_type(v) != 'table':
            return v
        keys = list(v.keys())
        if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
            return [self.py(v[k]) for k in sorted(keys)]
        return {k: self.py(v[k]) for k in keys}

    def call(self, name, *args):
        self.run('CLOCK = CLOCK + 1000')   # past the 400 ms gap between two uses
        return self.py(self.L.globals().CALL(name, *[self.to_lua(a) for a in args]))

    # ── the world ──
    def player(self, src, cid, job='unemployed', at=(0.0, 0.0, 0.0), staff=False):
        self.run("USERS[%d] = { cid = %r, job = %r, grade = 0 }; POS[%d] = vector3(%r, %r, %r); STAFF[%d] = %s"
                 % (src, cid, job, src, float(at[0]), float(at[1]), float(at[2]), src, 'true' if staff else 'nil'))

    def store(self, sid, name, owner=None, staff=(), at=(5.0, 0.0, 0.0), owner_name=None, enabled=True):
        staff_lua = '{' + ','.join('[%r]=true' % c for c in staff) + '}'
        self.run("STORES[%d] = { name = %r, owner = %s, ownerName = %s, staff = %s, at = { %r, %r, %r }, enabled = %s }"
                 % (sid, name, repr(owner) if owner else 'nil', repr(owner_name) if owner_name else 'nil', staff_lua,
                    float(at[0]), float(at[1]), float(at[2]), 'true' if enabled else 'false'))

    def door(self, door_id):
        return self.py(self.eval('Doors[%d]' % door_id))

    def row(self, door_id):
        return self.py(self.eval('(json.decode(ROWS[%d].data))' % door_id))

    def use(self, src, door_id, state, code=None):
        """The door's answer: True, 'passcode', or (False, why) - a trailing nil label is dropped"""
        res = self.call('w_doorlock:use', src, door_id, state, code)
        if isinstance(res, tuple):
            while res and res[-1] is None:
                res = res[:-1]
            if len(res) == 1:
                res = res[0]
        return res
