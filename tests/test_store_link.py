"""w_doorlock 2.2.0 (the owner, 2026-11-02): a door linked on the board to a w_store store opens and locks for that
store's owner and staff, asked of w_store on every use - the right follows a sale or a transfer, and with w_store
stopped the link grants nothing. The board refuses a link to a store w_store does not have. Real server Lua
(tests/harness.py)."""
import unittest

from harness import Server

GUN = 31                      # a player's gun store beside the door (Valentine, as on Red River)
DOOR = 1                      # the store's door: the law's (police) and the store's
OWNER, CLERK, STRANGER, LAW, ADMIN, BUYER = 1, 2, 3, 4, 5, 6


def door_row(**extra):
    row = {'name': 'gun_val', 'coords': {'x': 0.0, 'y': 0.0, 'z': 0.0}, 'hash': 475159788, 'model': 1, 'heading': 0,
           'state': 1, 'maxDistance': 2, 'groups': {'police': 0}}
    row.update(extra)
    return row


class Base(unittest.TestCase):
    door_extra = {'store': GUN}

    def setUp(self):
        s = self.s = Server({DOOR: door_row(**self.door_extra)})
        s.store(GUN, 'Barnes Guns', owner='c1', staff=('c2',), owner_name='Owner One')
        s.player(OWNER, 'c1')
        s.player(CLERK, 'c2')
        s.player(STRANGER, 'c3')
        s.player(LAW, 'c4', job='police')
        s.player(ADMIN, 'c5', staff=True)
        s.player(BUYER, 'c6')

    def state(self):
        return self.s.door(DOOR)['state']


class TestUse(Base):
    def test_the_owner_unlocks_and_locks(self):
        self.assertEqual(self.s.use(OWNER, DOOR, 0), True)
        self.assertEqual(self.state(), 0)
        self.assertEqual(self.s.use(OWNER, DOOR, 1), True)
        self.assertEqual(self.state(), 1)

    def test_the_staff_may(self):
        self.assertEqual(self.s.use(CLERK, DOOR, 0), True)
        self.assertEqual(self.state(), 0)

    def test_a_stranger_may_not_and_is_told_why(self):
        self.assertEqual(self.s.use(STRANGER, DOOR, 0), (False, 'not_group'))
        self.assertEqual(self.state(), 1)

    def test_the_law_still_may(self):
        self.assertEqual(self.s.use(LAW, DOOR, 0), True)

    def test_the_right_follows_a_sale(self):
        s = self.s
        s.run("STORES[%d].owner = 'c6' STORES[%d].staff = {}" % (GUN, GUN))   # w_store drops the staff on a sale
        self.assertEqual(s.use(OWNER, DOOR, 0), (False, 'not_group'))
        self.assertEqual(s.use(CLERK, DOOR, 0), (False, 'not_group'))
        self.assertEqual(s.use(BUYER, DOOR, 0), True)

    def test_nobody_through_a_government_store_or_the_bank_custody(self):
        s = self.s
        s.run("STORES[%d].owner = nil" % GUN)
        self.assertEqual(s.use(OWNER, DOOR, 0), (False, 'not_group'))
        s.run("STORES[%d].owner = 'escrow:7'" % GUN)
        self.assertEqual(s.use(OWNER, DOOR, 0), (False, 'not_group'))

    def test_w_store_stopped_grants_nothing_and_breaks_nothing(self):
        s = self.s
        s.run("STATES.w_store = 'stopped'")
        self.assertEqual(s.use(OWNER, DOOR, 0), (False, 'not_group'))
        self.assertEqual(s.use(LAW, DOOR, 0), True)
        s.run("STATES.w_store = 'started' STORE_THROWS = true")
        self.assertEqual(s.use(OWNER, DOOR, 1), (False, 'not_group'))
        self.assertFalse([p for p in s.py(s.eval('PRINTED')) or [] if 'Operation failed' in p])

    def test_the_owner_skips_a_code_like_a_listed_character(self):
        s = Server({DOOR: door_row(store=GUN, groups=None, passcode='1234')})
        s.store(GUN, 'Barnes Guns', owner='c1')
        s.player(OWNER, 'c1')
        s.player(STRANGER, 'c3')
        self.assertEqual(s.use(OWNER, DOOR, 0), True)
        self.assertEqual(s.use(STRANGER, DOOR, 0), 'passcode')

    def test_the_owner_must_stand_at_the_door(self):
        self.s.run('POS[%d] = vector3(40.0, 0.0, 0.0)' % OWNER)
        self.assertEqual(self.s.use(OWNER, DOOR, 0), (False, 'far'))

    def test_the_admins_autolock_still_locks_it_again(self):
        s = Server({DOOR: door_row(store=GUN, autolock=3)})
        s.store(GUN, 'Barnes Guns', owner='c1')
        s.player(OWNER, 'c1')
        self.assertEqual(s.use(OWNER, DOOR, 0), True)
        self.assertEqual(s.eval('TIMERS[1].ms'), 3000)
        s.run('FIRE_TIMERS()')
        self.assertEqual(s.door(DOOR)['state'], 1)

    def test_the_clients_never_hear_the_link(self):
        public = self.s.py(self.s.eval('DoorPublic(Doors[%d])' % DOOR))
        self.assertNotIn('store', public)


class TestUnlinked(Base):
    door_extra = {}

    def test_without_a_link_the_owner_is_a_stranger(self):
        self.assertEqual(self.s.use(OWNER, DOOR, 0), (False, 'not_group'))


class TestLoad(unittest.TestCase):
    def test_a_stored_link_is_a_whole_positive_id(self):
        s = Server({1: door_row(store='31'), 2: door_row(store=-4, hash=2), 3: door_row(store=3.5, hash=3),
                    4: door_row(store='x', hash=4), 5: door_row(hash=5)})
        self.assertEqual([s.door(i).get('store') for i in range(1, 6)], [31, None, None, None, None])


class TestBoard(Base):
    def form(self, **extra):
        f = {'name': 'gun_val', 'state': True, 'maxDistance': 2, 'groups': [{'name': 'police', 'grade': 0}]}
        f.update(extra)
        return f

    def save(self, door_id, form, who=ADMIN):
        return self.s.call('w_doorlock:admin:save', who, door_id, form)

    def test_staff_only(self):
        self.assertEqual(self.save(DOOR, self.form(store=GUN), who=OWNER), (False, 'no_permission'))
        self.assertFalse(self.s.call('w_doorlock:admin:stores', OWNER))

    def test_the_picker_lists_the_stores(self):
        s = self.s
        s.store(26, 'Saloon', at=(30.0, 2.0, 1.0))
        s.store(9, 'Closed', enabled=False)
        stores = s.call('w_doorlock:admin:stores', ADMIN)
        self.assertEqual([x['id'] for x in stores], [26, GUN])
        gun = next(x for x in stores if x['id'] == GUN)
        self.assertEqual((gun['name'], gun['owner'], gun['at']['x']), ('Barnes Guns', 'Owner One', 5.0))
        s.run("STATES.w_store = 'stopped'")
        self.assertFalse(s.call('w_doorlock:admin:stores', ADMIN))   # an empty table: nothing to pick

    def test_a_link_is_saved_with_the_door(self):
        s = Server({DOOR: door_row()})
        s.store(GUN, 'Barnes Guns', owner='c1')
        s.player(ADMIN, 'c5', staff=True)
        s.player(OWNER, 'c1')
        ok, door = s.call('w_doorlock:admin:save', ADMIN, DOOR, self.form(store=GUN))
        self.assertTrue(ok, door)
        self.assertEqual(door['store'], GUN)
        self.assertEqual(s.row(DOOR)['store'], GUN)
        self.assertEqual(s.use(OWNER, DOOR, 0), True)

    def test_an_unknown_store_is_refused_with_its_number(self):
        self.assertEqual(self.save(DOOR, self.form(store=999)), (False, 'unknown_store', '999'))
        self.assertEqual(self.s.row(DOOR)['store'], GUN)            # the door kept its link

    def test_a_new_link_waits_for_w_store(self):
        s = Server({DOOR: door_row()})
        s.store(GUN, 'Barnes Guns', owner='c1')
        s.player(ADMIN, 'c5', staff=True)
        s.run("STATES.w_store = 'stopped'")
        self.assertEqual(s.call('w_doorlock:admin:save', ADMIN, DOOR, self.form(store=GUN)), (False, 'store_offline'))

    def test_the_door_keeps_its_link_while_w_store_is_stopped(self):
        self.s.run("STATES.w_store = 'stopped'")
        ok, door = self.save(DOOR, self.form(store=GUN, autolock=0))
        self.assertTrue(ok, door)
        self.assertEqual(door['store'], GUN)

    def test_no_store_clears_the_link(self):
        for empty in (0, '', None, -1, 'abc'):
            s = Server({DOOR: door_row(store=GUN)})
            s.store(GUN, 'Barnes Guns', owner='c1')
            s.player(ADMIN, 'c5', staff=True)
            f = self.form()
            if empty is not None:
                f['store'] = empty
            ok, door = s.call('w_doorlock:admin:save', ADMIN, DOOR, f)
            self.assertTrue(ok, door)
            self.assertNotIn('store', door, empty)
            self.assertNotIn('store', s.row(DOOR), empty)

    def test_a_new_door_with_a_link(self):
        f = self.form(store=GUN, name='gun_back', hash=777, model=1, heading=0, coords={'x': 3.0, 'y': 0.0, 'z': 0.0})
        ok, door = self.save(None, f)
        self.assertTrue(ok, door)
        self.assertEqual(door['store'], GUN)
        f2 = dict(f, hash=778, store=12345)
        self.assertEqual(self.save(None, f2), (False, 'unknown_store', '12345'))

    def test_the_website_keeps_the_link_and_cannot_set_one(self):
        s = self.s
        s.run("INVOKER = 'w_connector'")
        res = s.py(s.eval("EXPORTED.SiteAdmin('edit', { id = %d, form = { name = 'renamed', store = 999 } }, 'web')" % DOOR))
        self.assertTrue(res['ok'], res)
        self.assertEqual(res['data']['store'], GUN)
        self.assertEqual(s.eval('ROWS[%d].name' % DOOR), 'renamed')
        self.assertEqual(s.row(DOOR)['store'], GUN)


if __name__ == '__main__':
    unittest.main()
