"""Exercise the real use callback: a citizen's job never grants all doors."""
import unittest

from harness import Server


def door(**extra):
    value = {'name': 'private', 'coords': {'x': 0, 'y': 0, 'z': 0},
             'hash': 9, 'state': 1, 'maxDistance': 2}
    value.update(extra)
    return value


class Authorisation(unittest.TestCase):
    def server(self, **extra):
        s = Server({1: door(**extra)})
        s.player(1, 'citizen')
        s.player(2, 'officer', job='police')
        s.player(3, 'staff', staff=True)
        return s

    def test_citizen_cannot_unlock_or_lock_a_job_door(self):
        s = self.server(groups={'police': 0})
        for state in (0, 1):
            self.assertEqual(s.use(1, 1, state), (False, 'not_group'))
        self.assertEqual(s.door(1)['state'], 1)

    def test_unloaded_player_cannot_use(self):
        s = self.server(groups={'police': 0})
        s.run('USERS[1] = nil')
        self.assertEqual(s.use(1, 1, 0), (False, 'cannot_unlock'))

    def test_job_and_minimum_grade_are_checked(self):
        s = self.server(groups={'police': 2})
        self.assertEqual(s.use(2, 1, 0), (False, 'not_group'))
        s.run('USERS[2].grade = 2')
        self.assertEqual(s.use(2, 1, 0), True)

    def test_admin_permission_alone_does_not_bypass_with_default_config(self):
        s = self.server(groups={'police': 0})
        self.assertEqual(s.use(3, 1, 0), (False, 'not_group'))
        s.run('Config.AdminBypass = true')
        self.assertEqual(s.use(3, 1, 0), True)

    def test_explicit_door_ace_authorises_only_its_holder(self):
        s = self.server(groups={'police': 0})
        s.run("function IsPlayerAceAllowed(src, node) return src == 3 and node == 'w_doorlock.door.private' end")
        self.assertEqual(s.use(1, 1, 0), (False, 'not_group'))
        self.assertEqual(s.use(3, 1, 0), True)

    def test_listed_character_has_access(self):
        s = self.server(characters=['citizen'])
        self.assertEqual(s.use(1, 1, 0), True)
        self.assertEqual(s.use(2, 1, 0), (False, 'not_allowed'))

    def test_door_without_rules_is_not_a_public_door(self):
        s = self.server()
        self.assertEqual(s.use(1, 1, 0), (False, 'not_allowed'))

    def test_code_door_asks_and_requires_correct_code(self):
        s = self.server(passcode='demo-code')
        self.assertEqual(s.use(1, 1, 0), 'passcode')
        self.assertEqual(s.use(1, 1, 0, 'wrong'), (False, 'wrong_code'))
        self.assertEqual(s.use(1, 1, 0, 'demo-code'), True)

    def test_item_is_authorised_and_consumed_only_when_removal_succeeds(self):
        s = self.server(items=[{'name': 'key', 'remove': True}])
        s.run("exports.w_lib.InvItems = function() return {label = 'Key'} end")
        self.assertEqual(s.use(1, 1, 0), (False, 'need_item', 'Key'))
        s.run('exports.w_lib.InvGetItemCount = function() return 1 end')
        s.run('exports.w_lib.InvRemoveItem = function() return false end')
        self.assertEqual(s.use(1, 1, 0), (False, 'cannot_unlock'))
        self.assertEqual(s.door(1)['state'], 1)
        s.run('exports.w_lib.InvRemoveItem = function() return true end')
        self.assertEqual(s.use(1, 1, 0), True)


if __name__ == '__main__':
    unittest.main()
