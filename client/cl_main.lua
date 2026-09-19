local wc = require('modules.client')

-- Set State for Specific Door --
RegisterNetEvent('w_doorlock:client:SyncDoorState', function(doorID, state) wc.SyncDoor(doorID, state) end)

-- Language switch ('w_lib:setLocale'): runs after the library reloaded this resource's dictionary --
w.i18n.onLocaleChange(function() wc.RelabelPrompts() end)

-- Player / Resource Handlers --
AddEventHandler('onResourceStart', function(resource) if resource == GetCurrentResourceName() then wc.CreateDoors() end end)
AddEventHandler('onResourceStop', function(resource) if resource == GetCurrentResourceName() then wc.RemovePoints() end end)
RegisterNetEvent('WCore:Client:OnPlayerLoaded', function() wc.CreateDoors() end)
RegisterNetEvent('WCore:Client:OnPlayerUnload', function() wc.RemovePoints() end)
