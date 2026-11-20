"""Run the actual client door code against an observable door-system simulation."""
from pathlib import Path
import unittest

from lupa import lua54

ROOT = Path(__file__).resolve().parents[1]
SIM = r'''
local vmeta = {}
vmeta.__sub = function(a,b) return vector3(a.x-b.x,a.y-b.y,a.z-b.z) end
vmeta.__len = function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
function vector3(x,y,z) return setmetatable({x=x,y=y,z=z}, vmeta) end
AT=vector3(0,0,0); NATIVE={}; CLOSED={}; ENTITIES={}; EXISTS={}; CALLS={}; THREADS={}; EVENTS={}
function CreateThread(fn) THREADS[#THREADS+1]=coroutine.create(fn) end
function Wait() coroutine.yield() end
function STEP(i) local ok,err=coroutine.resume(THREADS[i]); assert(ok,err) end
Citizen={ResultAsInteger=function() return 'integer' end}
function Citizen.InvokeNative(hash,a,b)
  if hash==0xD99229FE93B46286 then NATIVE[a]=NATIVE[a] or 0
  elseif hash==0x6BAB9442830C7F53 then
    NATIVE[a]=b; CALLS[#CALLS+1]={kind='state',hash=a,state=b}
  elseif hash==0x160AA1B32F6139B8 then return NATIVE[a] or -1
  elseif hash==0x276AAF0F1C7F2494 then
    CLOSED[a]=true; CALLS[#CALLS+1]={kind='shut',hash=a}
  else error('unmocked native') end
end
function GetEntityByDoorhash(hash) return ENTITIES[hash] or 0 end
function DoesEntityExist(entity)
  if EXISTS[entity]~=nil then return EXISTS[entity] end
  return entity~=0 and entity~=nil
end
function IsDoorClosed(hash) return CLOSED[hash] or false end
function PlayerPedId() return 1 end
function GetEntityCoords() return AT end
function GetEntityModel() return 1 end
function GetModelDimensions() return vector3(-.5,-.5,-.5),vector3(.5,.5,.5) end
function GetOffsetFromEntityInWorldCoords() return vector3(0,0,0) end
function DoorSystemSetAutomaticRate() end
function DoorSystemSetHoldOpen() end
function RegisterNetEvent(name,fn) EVENTS[name]=fn end
function TriggerEvent() end
function SendNUIMessage() end
function SetTimeout(_,fn) fn() end
function locale(key) return key end
w={callback={await=function() return LIST end}, print={warn=function() error('load failed') end}}
exports=setmetatable({w_lib={FwOnCharacterLoaded=function(_,fn) EVENTS['FwOnCharacterLoaded']=fn end}}, {__call=function() end})
'''


class ClientState(unittest.TestCase):
    def setUp(self):
        self.lua = lua54.LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(SIM)
        self.lua.execute((ROOT / 'shared/config.lua').read_text(encoding='utf-8'))
        self.lua.execute('''Config.UnlockedDoors={123,777}; LIST={
          {id=1,name='locked',hash=123,coords={x=0,y=0,z=0},state=1,maxDistance=2},
          {id=2,name='public',hash=456,coords={x=0,y=0,z=0},state=0,maxDistance=2}}
        ''')
        self.lua.execute((ROOT / 'client/doors.lua').read_text(encoding='utf-8'))
        self.g = self.lua.globals()
        self.g.STEP(1)  # initial load; the proximity worker is the second thread
        self.lua.execute('CALLS={}')

    def events(self, kind):
        return [c for _, c in self.g.CALLS.items() if c.kind == kind]

    def test_board_door_wins_over_public_door_list(self):
        self.assertEqual(self.g.NATIVE[123], 1)
        self.assertEqual(self.g.NATIVE[777], 0)

    def test_another_resource_cannot_leave_a_managed_door_unlocked(self):
        self.lua.execute('NATIVE[123]=0; CLOSED[123]=false; ENTITIES[123]=10')
        self.g.STEP(2)
        self.assertEqual(self.g.NATIVE[123], 1)
        self.assertTrue(self.g.CLOSED[123])

    def test_late_entity_gets_its_lock_even_if_state_was_already_cached(self):
        self.g.STEP(2)  # streamed entity not yet present
        self.lua.execute('CALLS={}; ENTITIES[123]=10; CLOSED[123]=0')
        self.g.STEP(2)
        self.assertEqual(self.g.NATIVE[123], 1)
        self.assertEqual(len([c for c in self.events('state') if c.hash == 123]), 1)
        self.assertTrue(self.g.CLOSED[123])

    def test_unlocked_door_is_reconciled_as_unlocked(self):
        self.lua.execute('NATIVE[456]=1; ENTITIES[456]=11; CLOSED[456]=false')
        self.g.STEP(2)
        self.assertEqual(self.g.NATIVE[456], 0)
        self.assertFalse([c for c in self.events('shut') if c.hash == 456])

    def test_steady_nearby_door_is_not_reset_every_tick(self):
        self.lua.execute('ENTITIES[123]=10; CLOSED[123]=true')
        self.g.STEP(2)
        self.lua.execute('CALLS={}')
        self.g.STEP(2)
        self.assertEqual(len(self.g.CALLS), 0)

    def test_far_door_is_not_polled_or_changed(self):
        self.lua.execute('AT=vector3(200,0,0); NATIVE[123]=0')
        self.g.STEP(2)
        self.assertEqual(self.g.NATIVE[123], 0)
        self.assertEqual(len(self.g.CALLS), 0)

    def test_removed_door_stays_out_of_reconciliation(self):
        self.g.EVENTS['w_doorlock:client:remove'](1)
        self.lua.execute('CALLS={}; NATIVE[123]=0; ENTITIES[123]=10')
        self.g.STEP(2)
        self.assertEqual(self.g.NATIVE[123], 0)
        self.assertEqual(len(self.g.CALLS), 0)

    def test_state_event_closes_a_door_for_numeric_false_native_result(self):
        self.lua.execute('CLOSED[123]=0')
        self.g.EVENTS['w_doorlock:client:setState'](1, 1)
        self.assertTrue(self.g.CLOSED[123])

    def test_each_leaf_of_a_double_door_is_reconciled(self):
        self.lua.execute('''
          EVENTS['w_doorlock:client:upsert']({id=3,name='double',coords={x=0,y=0,z=0},
            state=1,maxDistance=2,doors={
            {hash=801,coords={x=0,y=0,z=0}}, {hash=802,coords={x=0,y=0,z=0}}}})
          ENTITIES[801]=21; ENTITIES[802]=22; NATIVE[801]=0; NATIVE[802]=0
        ''')
        self.g.STEP(2)
        self.assertEqual(self.g.NATIVE[801], 1)
        self.assertEqual(self.g.NATIVE[802], 1)

    def test_unstreamed_leaf_does_not_generate_repeated_native_writes(self):
        self.lua.execute('NATIVE[123]=-1')
        self.g.STEP(2)
        self.g.STEP(2)
        self.assertEqual(len(self.g.CALLS), 0)

    def test_numeric_entity_despawn_clears_old_handle_and_registers_replacement(self):
        self.lua.execute('ENTITIES[123]=10; EXISTS[10]=1; CLOSED[123]=true')
        self.g.STEP(2)
        self.assertEqual(self.g.WDoor.EntityDoor[10], 1)
        self.lua.execute('CALLS={}; EXISTS[10]=0; ENTITIES[123]=0')
        self.g.STEP(2)
        self.assertIsNone(self.g.WDoor.Doors[1].entity)
        self.assertIsNone(self.g.WDoor.EntityDoor[10])
        self.assertEqual(len(self.g.CALLS), 0)
        self.lua.execute('ENTITIES[123]=11; EXISTS[11]=1; CLOSED[123]=0')
        self.g.STEP(2)
        self.assertEqual(self.g.WDoor.Doors[1].entity, 11)
        self.assertEqual(self.g.WDoor.EntityDoor[11], 1)
        self.assertIsNone(self.g.WDoor.EntityDoor[10])
        self.assertTrue(self.g.CLOSED[123])

    def test_nonexistent_handle_from_door_hash_is_not_accepted(self):
        self.lua.execute('ENTITIES[123]=91; EXISTS[91]=0; NATIVE[123]=0')
        self.g.STEP(2)
        self.assertIsNone(self.g.WDoor.Doors[1].entity)
        self.assertIsNone(self.g.WDoor.EntityDoor[91])
        self.assertEqual(len(self.g.CALLS), 0)


if __name__ == '__main__':
    unittest.main()
