-- Lấy config từ file config.lua
local TOMTICH_ZONE = Config.TomTichZone
local SPAWN_COOLDOWN = 180 -- 180 giây cooldown

-- Trạng thái minigame tôm tích
local isTomTichActive = false
local lastPlayTime = 0 -- Thời gian chơi lần cuối
local lastPlayPosition = nil -- Vị trí chơi lần cuối
local MIN_DISTANCE_BETWEEN_PLAYS = 5.0 -- Khoảng cách tối thiểu giữa các lần chơi (đơn vị: bước chân)

-- Trạng thái minigame kho báu
local isTreasureActive = false

-- Player level
local playerLevel = 1

-- Dừng animation (Helper)
local function StopScratchAnimation()
    local playerPed = PlayerPedId()
    ClearPedTasks(playerPed)
end

-- ============================================
-- NOTIFICATION HELPER
-- ============================================
-- Nhận thông báo
RegisterNetEvent('cautomtich:notification')
AddEventHandler('cautomtich:notification', function(item, reason)
    local messages = {
        tomtich_success = "🎉 Chúc mừng! Bạn đã câu được Tôm Tích!",
        tomtich_fail = "😔 Thất bại! Bạn nhận được Rác thải nhựa"
    }
    
    local message = messages[reason] or reason or "Bạn đã nhận được phần thưởng!"
    no:Notify(message, 'success', 5000)
end)

-- Nhận cập nhật level từ server
RegisterNetEvent('tomtich:updateLevel')
AddEventHandler('tomtich:updateLevel', function(level, exp)
    playerLevel = level
    SendNUIMessage({
        action = "updateLevel",
        level = level,
        exp = exp
    })
end)

-- Callback từ NUI
RegisterNUICallback('closeTomTich', function(data, cb)
    CloseTomTichGame()
    cb('ok')
end)

-- Hàm vẽ text 3D
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)
    local factor = (string.len(text)) / 370
    DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 75)
end


-- ============================================
-- MINIGAME TÔM TÍCH
-- ============================================

-- Animation đào cát
local function PlayDiggingAnimation()
    local playerPed = PlayerPedId()
    
    RequestAnimDict(Config.DiggingAnimation.dict)
    while not HasAnimDictLoaded(Config.DiggingAnimation.dict) do
        Citizen.Wait(100)
    end
    
    TaskPlayAnim(playerPed, Config.DiggingAnimation.dict, Config.DiggingAnimation.name, 8.0, -8.0, -1, 1, 0, false, false, false)
end

-- Mở UI tôm tích
function OpenTomTichGame()
    if isTomTichActive then
        return
    end
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local currentTime = GetGameTimer() / 1000
    
    isTomTichActive = true
    
    -- Hiển thị progress bar đào cát
    PlayDiggingAnimation()
    
    local diggingTime = math.random(10000, 15000) -- 10-15 giây
    
    QBCore.Functions.Progressbar("digging_sand", "🏖️ Đang đào cát tìm tôm...", diggingTime, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        -- Hoàn thành đào cát
        StopScratchAnimation()
        
        -- Kiểm tra cooldown SAU KHI đào xong
        if currentTime - lastPlayTime < SPAWN_COOLDOWN then
            local remainingTime = math.ceil(SPAWN_COOLDOWN - (currentTime - lastPlayTime))
            local minutes = math.floor(remainingTime / 60)
            local seconds = remainingTime % 60
            TriggerEvent('cautomtich:notification', nil, string.format("⏱️ Khu vực này không thấy tôm", minutes, seconds))
            isTomTichActive = false
            return
        end
        
        -- Kiểm tra vị trí (tránh đứng 1 chỗ chơi liên tục)
        if lastPlayPosition then
            local distance = #(playerCoords - lastPlayPosition)
            if distance < MIN_DISTANCE_BETWEEN_PLAYS then
                TriggerEvent('cautomtich:notification', nil, "🦐 Tôm ở đây đã bắt hết rồi! Hãy di chuyển sang chỗ khác.")
                isTomTichActive = false
                return
            end
        end
        
        -- Lưu thời gian và vị trí chơi
        lastPlayTime = GetGameTimer() / 1000
        lastPlayPosition = playerCoords
        
        -- Mở minigame
        TriggerServerEvent('tomtich:startGame')
        
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "showTomTich"
        })
    end, function() -- Cancel
        -- Hủy bỏ
        StopScratchAnimation()
        isTomTichActive = false
        TriggerEvent('cautomtich:notification', nil, "❌ Đã hủy đào cát")
    end)
end

-- Đóng UI tôm tích
function CloseTomTichGame()
    isTomTichActive = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "hideTomTich"
    })
    
    StopScratchAnimation()
end

-- Command test
RegisterCommand('tomtich', function()
    OpenTomTichGame()
end, false)

RegisterCommand('treasure', function()
    -- Bỏ check level để test
    OpenTreasureGame(true)  -- Skip cooldown cho test command
end, false)

-- Command test trigger event kho báu
RegisterCommand('testtreasureevent', function()
    TriggerEvent('tomtich:showTreasureAfterGame')
end, false)

-- Command để set level test
RegisterCommand('setlevel', function(source, args)
    local level = tonumber(args[1]) or 1
    playerLevel = math.min(3, math.max(1, level))
    TriggerEvent('cautomtich:notification', nil, "Đã set level: " .. playerLevel)
end, false)

-- Nhận kết quả từ server
RegisterNetEvent('tomtich:gameResult')
AddEventHandler('tomtich:gameResult', function(success, item)
    SendNUIMessage({
        action = "tomtichResult",
        success = success,
        item = item
    })
    
    -- Không tự động đóng nữa - để server quyết định
    -- Citizen.SetTimeout(3000, function()
    --     CloseTomTichGame()
    -- end)
end)

-- Nhận sự kiện hiển thị kho báu sau khi câu tôm thành công (Level 3)
RegisterNetEvent('tomtich:showTreasureAfterGame')
AddEventHandler('tomtich:showTreasureAfterGame', function()
    -- Đóng UI tôm tích trước
    CloseTomTichGame()
    
    -- Hiển thị thông báo
    TriggerEvent('cautomtich:notification', nil, "🎉 Phát hiện Kho Báu gần đây! Hãy đào ngay!")
    
    -- Delay 1 giây rồi mở minigame kho báu (SKIP COOLDOWN vì đây là reward)
    Citizen.SetTimeout(1000, function()
        OpenTreasureGame(true)  -- true = skip cooldown
    end)
end)

-- Event đóng UI tôm tích thông thường (không có kho báu)
RegisterNetEvent('tomtich:closeUI')
AddEventHandler('tomtich:closeUI', function()
    Citizen.SetTimeout(3000, function()
        CloseTomTichGame()
    end)
end)

-- Callback từ NUI
RegisterNUICallback('tomtichAttempt', function(data, cb)
    TriggerServerEvent('tomtich:attempt', data.success, data.item, data.customMessage)
    cb('ok')
end)

-- ============================================
-- MINIGAME KHO BÁU
-- ============================================

function OpenTreasureGame(skipCooldown)
    if isTreasureActive then
        return
    end
    
    isTreasureActive = true
    
    TriggerServerEvent('treasure:startGame')
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "showTreasure"
    })
end

function CloseTreasureGame()
    isTreasureActive = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "hideTreasure"
    })
    TriggerServerEvent('treasure:close')
end

RegisterNUICallback('closeTreasure', function(data, cb)
    CloseTreasureGame()
    cb('ok')
end)

RegisterNUICallback('treasureOpenCell', function(data, cb)
    TriggerServerEvent('treasure:openCell', data.cellIndex)
    cb('ok')
end)

RegisterNetEvent('treasure:gameData')
AddEventHandler('treasure:gameData', function(data)
    SendNUIMessage({
        action = "treasureGameData",
        data = data
    })
end)

RegisterNetEvent('treasure:cellResult')
AddEventHandler('treasure:cellResult', function(data)
    SendNUIMessage({
        action = "treasureCellResult",
        data = data
    })
end)

RegisterNetEvent('treasure:gameEnd')
AddEventHandler('treasure:gameEnd', function(data)
    SendNUIMessage({
        action = "treasureGameEnd",
        data = data
    })
    
    Citizen.SetTimeout(5000, function()
        CloseTreasureGame()
    end)
end)

-- Tạo 1 vùng zone lớn cho câu tôm (hình chữ nhật)
Citizen.CreateThread(function()
    local zone = lib.zones.box({
        coords = TOMTICH_ZONE.coords,
        size = TOMTICH_ZONE.size,
        rotation = TOMTICH_ZONE.rotation,
        debug = true, -- Bật debug để hiển thị viền zone
        inside = function()
            if IsControlJustReleased(0, 38) then -- Phím E
                OpenTomTichGame()
            end
        end,
        onEnter = function()
            lib.showTextUI('[E] Đào cát tìm tôm', {
                position = "top-center",
                icon = 'hand',
                style = {
                    borderRadius = 5,
                    backgroundColor = '#48BB78',
                    color = 'white'
                }
            })
        end,
        onExit = function()
            lib.hideTextUI()
        end
    })
end)


