fx_version "cerulean"
games { "rdr3" }
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

description 'Doorlock Handler for Wraith Core RedM'
author 'Wraith Studio'

-- w_lib first: it provides `w`, `cache` and the resource-relative `require` used below
shared_scripts { '@w_lib/init.lua', 'shared/*.lua' }

-- preload the dictionary (locales/{ar,en}.json) on both sides
w_lib { 'locale' }
client_scripts { 'client/*.lua' }
server_scripts { 'server/*.lua' }

-- modules/*.lua are loaded once through require('modules.<name>'), never as plain scripts.
-- The client copy must be shipped as a file so LoadResourceFile can read it client-side.
files { 'modules/client.lua', 'locales/*.json' }

-- w_core too: its core object is fetched at load (w.framework:getCoreObject())
dependencies { 'w_lib' }
