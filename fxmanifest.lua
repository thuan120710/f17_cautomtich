fx_version 'cerulean'
game 'gta5'

author 'FiveM Developer'
description 'Mini Game Câu Tôm Tích'
version '1.0.0'

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
    'html/style.css',
    'html/script.js',
    'html/images/*.png',
    'html/images/*.jpg',
    'html/sounds/*.mp3',
    'html/sounds/*.ogg'
}
