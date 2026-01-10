fx_version 'cerulean'
game 'gta5'

author 'FiveM Developer'
description 'Mini Game Câu Tôm Tích'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
	'config.lua',
}

-- Server scripts
server_scripts {
    'server/main.lua'
}

-- Client scripts
client_scripts {
    'client/main.lua'
}

-- UI files
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/script.js',
    'html/style.css',
    'html/images/*.png',
    'html/images/*.jpg',
    'html/sounds/*.mp3',
    'html/sounds/*.ogg'
}
