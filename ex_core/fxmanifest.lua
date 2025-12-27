fx_version "cerulean"
game "gta5"
lua54 "yes"

author "Leoneo223"
version "1.0.0"
description "ExtraM Core logic - Framework that will work like GTA:O but in FiveM"

shared_script {
    "config.lua"
}

client_scripts {
    "lib/client.lua",
    "src/client.lua"
}

server_scripts {
    "@mysql-async/lib/MySQL.lua",
    "lib/server.lua",
    "src/server.lua"
}

exports {
    'GiveStat',
    'RemoveStat',
    'GetPlayer',
    'Withdraw',
    'Deposit'
}

dependencies {
    "mysql-async",
    "NativeUI"
}
