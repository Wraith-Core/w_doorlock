-- ════════════════════════════════════════════════════════════════════════════
-- w_doorlock · data/legacy.lua
-- The doors of the previous w_doorlock (its shared/sh_doors.lua, rsg-doorlock's format), converted
-- to this script's shape. server/db.lua adds them to the table ONCE, on the first start, skipping
-- any door whose hash the table already holds; after that they are ordinary doors on the board.
--
--   jobs = { 'police' }   ->  groups = { police = 0 }      (every grade)
--   doorid                ->  hash
--   objCoords / objYaw    ->  coords / heading
--   locked / distance     ->  state (1 locked, 0 open) / maxDistance
--   double                ->  doors = { { hash, coords, heading }, { ... } }, coords = the middle
-- ════════════════════════════════════════════════════════════════════════════
return {

    -- Valentine Sheriff Office
    {
        name = 'valentine_sheriff_front',
        hash = 1988748538, coords = { x = -276.0126037597656, y = 802.591064453125, z = 118.41165161132812 }, heading = 10,
        state = 1, maxDistance = 2.0, groups = { police = 0 },
    },
    {
        name = 'valentine_sheriff_back',
        hash = 395506985, coords = { x = -275.8447570800781, y = 812.0270385742188, z = 118.41483306884766 }, heading = -170,
        state = 1, maxDistance = 2.0, groups = { police = 0 },
    },
    {
        name = 'valentine_sheriff_cells_back',
        hash = 1508776842, coords = { x = -270.76641845703125, y = 810.0264892578125, z = 118.39580535888672 }, heading = -80,
        state = 1, maxDistance = 1.5, groups = { police = 0 },
    },
    {
        name = 'valentine_sheriff_cell_area',
        hash = 535323366, coords = { x = -275.0232849121094, y = 809.2740478515625, z = 118.36856842041016 }, heading = -80,
        state = 1, maxDistance = 1.5, groups = { police = 0 },
    },
    {
        name = 'valentine_sheriff_cell_1',
        hash = 295355979, coords = { x = -273.4643249511719, y = 809.966064453125, z = 118.36823272705078 }, heading = 10,
        state = 1, maxDistance = 1.5, groups = { police = 0 },
    },
    {
        name = 'valentine_sheriff_cell_2',
        hash = 193903155, coords = { x = -272.0520935058594, y = 808.25830078125, z = 118.36851501464844 }, heading = -170,
        state = 1, maxDistance = 1.5, groups = { police = 0 },
    },

    -- Rhodes Sheriff Office
    {
        name = 'rhodes_sheriff_front',
        hash = 349074475, coords = { x = 1359.710205078125, y = -1305.9600830078125, z = 76.76842498779297 }, heading = 160,
        state = 1, maxDistance = 2.0, groups = { police = 0 },
    },
    {
        name = 'rhodes_sheriff_back',
        hash = 1614494720, coords = { x = 1359.097900390625, y = -1297.5343017578125, z = 76.78761291503906 }, heading = -110,
        state = 1, maxDistance = 2.0, groups = { police = 0 },
    },
    {
        name = 'rhodes_sheriff_cell',
        hash = 1878514758, coords = { x = 1357.3343505859375, y = -1302.4530029296875, z = 76.76018524169922 }, heading = 70,
        state = 1, maxDistance = 1.5, groups = { police = 0 },
    },

    -- Blackwater Sheriff Office
    {
        name = 'blackwater_sheriff_front',
        coords = { x = -757.0421447753906, y = -1269.2042846679688, z = 43.06861686706543 },
        doors = {
            { hash = 3410720590, coords = { x = -757.0421752929688, y = -1268.485107421875, z = 43.068603515625 }, heading = 90 },
            { hash = 3821185084, coords = { x = -757.0421142578125, y = -1269.9234619140625, z = 43.06863021850586 }, heading = 90 },
        },
        state = 1, maxDistance = 2.0, groups = { police = 0 },
    },
    {
        name = 'blackwater_sheriff_back',
        hash = 2810801921, coords = { x = -769.1370849609375, y = -1268.7451171875, z = 43.0400390625 }, heading = -90,
        state = 1, maxDistance = 2.0, groups = { police = 0 },
    },
    {
        name = 'blackwater_sheriff_cell_1',
        hash = 2167775834, coords = { x = -763.52783203125, y = -1262.4608154296875, z = 43.02327346801758 }, heading = -90,
        state = 1, maxDistance = 1.5, groups = { police = 0 },
    },
    {
        name = 'blackwater_sheriff_cell_2',
        hash = 2514996159, coords = { x = -765.8607788085938, y = -1264.7044677734375, z = 43.02326965332031 }, heading = 90,
        state = 1, maxDistance = 1.5, groups = { police = 0 },
    },

    -- Strawberry Sheriff Office
    {
        name = 'strawberry_sheriff_front',
        hash = 1821044729, coords = { x = -1806.6751708984375, y = -350.31280517578125, z = 163.64759826660156 }, heading = -115,
        state = 1, maxDistance = 2.0, groups = { police = 0 },
    },
    {
        name = 'strawberry_sheriff_cell_1',
        hash = 902070893, coords = { x = -1814.400390625, y = -353.1470947265625, z = 160.44180297851562 }, heading = -115,
        state = 1, maxDistance = 1.5, groups = { police = 0 },
    },
    {
        name = 'strawberry_sheriff_cell_2',
        hash = 1207903970, coords = { x = -1812.0101318359375, y = -351.92095947265625, z = 160.46839904785156 }, heading = -25,
        state = 1, maxDistance = 1.5, groups = { police = 0 },
    },
    {
        name = 'strawberry_sheriff_back',
        hash = 1514359658, coords = { x = -1812.669189453125, y = -345.08489990234375, z = 163.64759826660156 }, heading = -115,
        state = 1, maxDistance = 2.0, groups = { police = 0 },
    },

    -- Saint Denis Police HQ
    {
        name = 'saintdenis_police_front',
        coords = { x = 2516.1444091796875, y = -1308.8262329101562, z = 47.95257186889648 },
        doors = {
            { hash = 417663242, coords = { x = 2516.144287109375, y = -1309.9276123046875, z = 47.95257186889648 }, heading = 90 },
            { hash = 1611175760, coords = { x = 2516.14453125, y = -1307.724853515625, z = 47.95257186889648 }, heading = -90 },
        },
        state = 0, maxDistance = 2.0, groups = { police = 0 },
    },
    {
        name = 'saintdenis_police_inside_left',
        coords = { x = 2510.90771484375, y = -1311.3497314453125, z = 47.95257186889648 },
        doors = {
            { hash = 3601535313, coords = { x = 2510.90771484375, y = -1312.2154541015625, z = 47.95257186889648 }, heading = -90 },
            { hash = 3430284519, coords = { x = 2510.90771484375, y = -1310.4840087890625, z = 47.95257186889648 }, heading = -90 },
        },
        state = 1, maxDistance = 2.0, groups = { police = 0 },
    },
    {
        name = 'saintdenis_police_inside_right',
        coords = { x = 2510.90771484375, y = -1306.2764892578125, z = 47.95716857910156 },
        doors = {
            { hash = 3124713594, coords = { x = 2510.90771484375, y = -1307.141357421875, z = 47.95716857910156 }, heading = -90 },
            { hash = 1879655431, coords = { x = 2510.90771484375, y = -1305.41162109375, z = 47.95716857910156 }, heading = -90 },
        },
        state = 1, maxDistance = 2.0, groups = { police = 0 },
    },
    {
        name = 'saintdenis_police_side_1',
        coords = { x = 2507.471923828125, y = -1317.2796630859375, z = 47.95257186889648 },
        doors = {
            { hash = 1020479727, coords = { x = 2508.337646484375, y = -1317.2796630859375, z = 47.95257186889648 }, heading = 180 },
            { hash = 603068205, coords = { x = 2506.606201171875, y = -1317.2796630859375, z = 47.95257186889648 }, heading = 180 },
        },
        state = 1, maxDistance = 2.0, groups = { police = 0 },
    },
    {
        name = 'saintdenis_police_side_2',
        coords = { x = 2496.819091796875, y = -1317.28271484375, z = 47.95257186889648 },
        doors = {
            { hash = 305296302, coords = { x = 2497.684814453125, y = -1317.28271484375, z = 47.95257186889648 }, heading = 180 },
            { hash = 2503834054, coords = { x = 2495.953369140625, y = -1317.28271484375, z = 47.95257186889648 }, heading = 180 },
        },
        state = 1, maxDistance = 2.0, groups = { police = 0 },
    },
    {
        name = 'saintdenis_police_back_1',
        coords = { x = 2493.37255859375, y = -1311.0908813476562, z = 47.95257186889648 },
        doors = {
            { hash = 1992193795, coords = { x = 2493.37255859375, y = -1311.95654296875, z = 47.95257186889648 }, heading = 90 },
            { hash = 1694749582, coords = { x = 2493.37255859375, y = -1310.2252197265625, z = 47.95257186889648 }, heading = 90 },
        },
        state = 1, maxDistance = 2.0, groups = { police = 0 },
    },
    {
        name = 'saintdenis_police_back_2',
        coords = { x = 2493.37255859375, y = -1306.552734375, z = 47.95257186889648 },
        doors = {
            { hash = 1979938193, coords = { x = 2493.37255859375, y = -1307.41845703125, z = 47.95257186889648 }, heading = 90 },
            { hash = 1674105116, coords = { x = 2493.37255859375, y = -1305.68701171875, z = 47.95257186889648 }, heading = 90 },
        },
        state = 1, maxDistance = 2.0, groups = { police = 0 },
    },
    {
        name = 'saintdenis_police_cell_1',
        hash = 3365520707, coords = { x = 2498.5, y = -1307.85595703125, z = 47.95327377319336 }, heading = 0,
        state = 1, maxDistance = 1.5, groups = { police = 0 },
    },
    {
        name = 'saintdenis_police_cell_2',
        hash = 1995743734, coords = { x = 2499.752197265625, y = -1309.8763427734375, z = 47.95327377319336 }, heading = 180,
        state = 1, maxDistance = 1.5, groups = { police = 0 },
    },
    {
        name = 'saintdenis_police_cell_3',
        hash = 1711767580, coords = { x = 2502.4296875, y = -1307.85595703125, z = 47.95327377319336 }, heading = 0,
        state = 1, maxDistance = 1.3, groups = { police = 0 },
    },
    {
        name = 'saintdenis_police_cell_4',
        hash = 2515591150, coords = { x = 2503.638671875, y = -1309.8763427734375, z = 47.95327377319336 }, heading = 180,
        state = 1, maxDistance = 1.3, groups = { police = 0 },
    },
}
