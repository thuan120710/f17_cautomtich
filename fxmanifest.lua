name 'f17_cautomtit'
author 'Thảo#3922'
version 'v2.0.0'
description 'f17_cautomtit | Hệ thống nghề tôm tít by F17 Team'
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

 shared_scripts {
    '@ox_lib/init.lua',
	'config.lua',
    'shared.lua'
}

client_scripts {
    'main_fc.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/images/*.png',
    'html/images/*.jpg',
    'html/sounds/*.mp3',
    'html/sounds/*.ogg'
}