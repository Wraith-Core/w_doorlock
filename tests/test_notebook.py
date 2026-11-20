"""The notebook board (2026-11-12): the board's two new server calls - the names it shows instead of keys
(w_doorlock:admin:names) and the world mode's lock / unlock (w_doorlock:admin:lock) - are for the staff only, and
the lock goes through the one way a door changes (DoorSetState: every client told, stateChanged with the staff
member). Real server Lua (tests/harness.py)."""
import unittest

from harness import Server

DOOR = 1
STAFF, CITIZEN = 1, 2


def door_row(**extra):
    row = {'name': 'valentine_sheriff_front', 'coords': {'x': 0.0, 'y': 0.0, 'z': 0.0}, 'hash': 1988748538,
           'heading': 10, 'state': 1, 'maxDistance': 2, 'groups': {'police': 0}}
    row.update(extra)
    return row


class Notebook(unittest.TestCase):
    def setUp(self):
        s = self.s = Server({DOOR: door_row()})
        s.player(STAFF, 'c1', staff=True)
        s.player(CITIZEN, 'c2', job='police')

    def test_names_are_for_the_staff(self):
        self.assertFalse(self.s.call('w_doorlock:admin:names', CITIZEN))
        got = self.s.call('w_doorlock:admin:names', STAFF)
        self.assertIsInstance(got, dict)
        # no core / bag answering: empty lists, the board then types the keys as before
        self.assertEqual(got.get('groups') or [], [])
        self.assertEqual(got.get('items') or [], [])

    def test_names_come_from_w_core_with_their_grades(self):
        s = self.s
        s.run("""
            exports.w_lib.FwGetSharedJobs = function() return {
                police = { label = 'Sheriff', label_ar = 'الشريف', grades = { ['0'] = { name = 'Deputy', name_ar = 'نائب' },
                                                                              ['2'] = { name = 'Sergeant', name_ar = 'رقيب' } } },
                doctor = { label = 'Doctor', grades = {} },
            } end
            exports.w_lib.FwGetSharedGangs = function() return { odriscoll = { label = "O'Driscolls", label_ar = 'أودريسكول', grades = {} } } end
        """)
        got = s.call('w_doorlock:admin:names', STAFF)
        groups = got['groups']
        self.assertEqual([g['name'] for g in groups], ['doctor', 'police', 'odriscoll'])   # jobs first, then gangs
        police = groups[1]
        self.assertEqual((police['kind'], police['ar'], police['en']), ('job', 'الشريف', 'Sheriff'))
        self.assertEqual([(x['grade'], x['ar']) for x in police['grades']], [(0, 'نائب'), (2, 'رقيب')])
        self.assertEqual(groups[0]['ar'], 'Doctor')        # no Arabic name: the English one
        self.assertEqual(groups[2]['kind'], 'gang')

    def test_lock_is_for_the_staff(self):
        res = self.s.call('w_doorlock:admin:lock', CITIZEN, DOOR, False)
        self.assertEqual(res[0] if isinstance(res, tuple) else res, False)
        self.assertEqual(self.s.door(DOOR)['state'], 1)

    def test_lock_and_unlock_through_the_one_way_a_door_changes(self):
        s = self.s
        ok = s.call('w_doorlock:admin:lock', STAFF, DOOR, False)
        self.assertEqual(ok[0] if isinstance(ok, tuple) else ok, True)
        self.assertEqual(s.door(DOOR)['state'], 0)
        told = s.py(s.eval("CLIENT[#CLIENT]"))
        self.assertEqual(told['name'], 'w_doorlock:client:setState')
        heard = s.py(s.eval("EVENTS[#EVENTS]"))
        self.assertEqual(heard['name'], 'w_doorlock:stateChanged')
        self.assertEqual(heard['args'][1], STAFF)          # the staff member is named, like a player's use
        s.call('w_doorlock:admin:lock', STAFF, DOOR, True)
        self.assertEqual(s.door(DOOR)['state'], 1)

    def test_lock_refuses_a_missing_door_or_a_bad_state(self):
        res = self.s.call('w_doorlock:admin:lock', STAFF, 99, True)
        self.assertEqual(res, (False, 'missing'))
        res = self.s.call('w_doorlock:admin:lock', STAFF, DOOR, 'yes')
        self.assertEqual(res, (False, 'invalid'))
        self.assertEqual(self.s.door(DOOR)['state'], 1)


if __name__ == '__main__':
    unittest.main()
