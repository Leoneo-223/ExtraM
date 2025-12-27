fx_version 'cerulean'
game 'gta5'

author 'lambups'
version '1.0.0'

client_script '@NativeUI/NativeUI.lua'
client_script 'client.lua'
server_script '@mysql-async/lib/MySQL.lua'
server_script 'server.lua'
shared_script 'shared.lua'

dependency 'NativeUI'
