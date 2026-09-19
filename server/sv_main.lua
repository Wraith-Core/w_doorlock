local ws = require('modules.server')

-- Get Door States --
w.callback.register('w_doorlock:server:SyncDoors', function(source) return Doors.List end)

-- Update Door State on Server --
w.callback.register('w_doorlock:server:UpdateState', function(source, ID, STATE) return ws.UpdateState(source, ID, STATE) end)