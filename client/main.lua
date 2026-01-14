-- Điểm câu tôm tích
local TOMTICH_POINT = vector3(-1903.75, -827.08, 0.56)

-- Điểm đào kho báu (Level 3 only)
local TREASURE_POINT = vector4(-1525.51, -1269.09, 2.09, 220.49)

local SPAWN_COOLDOWN = 5  -- 5 giây (Test)
local INTERACTION_DISTANCE = 2.0  -- Khoảng cách tương tác

-- Trạng thái minigame tôm tích
local isTomTichActive = false
local tomtichState = {
    available = true,
    lastUsed = 0
}

-- Trạng thái minigame kho báu
local isTreasureActive = false
local treasureState = {
    available = true,
    lastUsed = 0
}

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

-- Animation câu tôm
local function PlayFishingAnimation()
    local playerPed = PlayerPedId()
    
    RequestAnimDict("amb@world_human_stand_fishing@idle_a")
    while not HasAnimDictLoaded("amb@world_human_stand_fishing@idle_a") do
        Citizen.Wait(100)
    end
    
    TaskPlayAnim(playerPed, "amb@world_human_stand_fishing@idle_a", "idle_c", 8.0, -8.0, -1, 49, 0, false, false, false)
end

-- Mở UI tôm tích
function OpenTomTichGame()
    if isTomTichActive then
        return
    end
    
    isTomTichActive = true
    tomtichState.available = false
    tomtichState.lastUsed = GetGameTimer() / 1000
    
    PlayFishingAnimation()
    
    TriggerServerEvent('tomtich:startGame')
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "showTomTich"
    })
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
    print("🧪 [TEST] Trigger event showTreasureAfterGame")
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
    print("🎁 [CLIENT DEBUG] Nhận event showTreasureAfterGame")
    
    -- Đóng UI tôm tích trước
    CloseTomTichGame()
    
    -- Hiển thị thông báo
    TriggerEvent('cautomtich:notification', nil, "🎉 Phát hiện Kho Báu gần đây! Hãy đào ngay!")
    
    -- Delay 1 giây rồi mở minigame kho báu (SKIP COOLDOWN vì đây là reward)
    Citizen.SetTimeout(1000, function()
        print("🎁 [CLIENT DEBUG] Mở minigame kho báu (skip cooldown)")
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
        print("⚠️ [CLIENT DEBUG] Kho báu đang active, không mở lại")
        return
    end
    
    -- Bỏ check level để test
    -- if playerLevel < 3 then
    --     TriggerEvent('cautomtich:notification', nil, "Cần Level 3 để mở kho báu!")
    --     return
    -- end
    
    print("🎁 [CLIENT DEBUG] OpenTreasureGame được gọi - skipCooldown: " .. tostring(skipCooldown))
    
    isTreasureActive = true
    
    -- Chỉ set cooldown nếu KHÔNG skip (tức là mở từ marker)
    if not skipCooldown then
        treasureState.available = false
        treasureState.lastUsed = GetGameTimer() / 1000
        print("🕐 [CLIENT DEBUG] Set cooldown cho treasure")
    else
        print("⏭️ [CLIENT DEBUG] Skip cooldown (mở từ event)")
    end
    
    TriggerServerEvent('treasure:startGame')
    
    print("🎁 [CLIENT DEBUG] Đang set NUI focus và gửi message showTreasure")
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "showTreasure"
    })
    print("🎁 [CLIENT DEBUG] Đã gửi showTreasure message đến NUI")
end

function CloseTreasureGame()
    print("🔒 [CLIENT DEBUG] CloseTreasureGame được gọi")
    isTreasureActive = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "hideTreasure"
    })
    TriggerServerEvent('treasure:close')
    print("🔒 [CLIENT DEBUG] Treasure đã đóng - isTreasureActive: " .. tostring(isTreasureActive))
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

-- Thread cập nhật cooldown tôm tích
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        
        local currentTime = GetGameTimer() / 1000
        
        if not tomtichState.available then
            local timeSinceUsed = currentTime - tomtichState.lastUsed
            if timeSinceUsed >= SPAWN_COOLDOWN then
                tomtichState.available = true
            end
        end
        
        if not treasureState.available then
            local timeSinceUsed = currentTime - treasureState.lastUsed
            if timeSinceUsed >= SPAWN_COOLDOWN then
                treasureState.available = true
            end
        end
    end
end)

-- Thread hiển thị marker tôm tích
Citizen.CreateThread(function()
    while true do
        local sleep = 500
        
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local distance = #(playerCoords - TOMTICH_POINT)
        
        if distance < 50.0 then
            sleep = 0
            
            if tomtichState.available then
                -- Marker xanh lá (available)
                DrawMarker(
                    1,
                    TOMTICH_POINT.x, TOMTICH_POINT.y, TOMTICH_POINT.z - 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    1.5, 1.5, 1.0,
                    0, 255, 150, 150,
                    false, true, 2, false, nil, nil, false
                )
                
                if distance < INTERACTION_DISTANCE then
                    DrawText3D(TOMTICH_POINT.x, TOMTICH_POINT.y, TOMTICH_POINT.z + 0.5, "[~g~E~w~] Câu Tôm Tích")
                    
                    if IsControlJustReleased(0, 38) then
                        OpenTomTichGame()
                    end
                end
            else
                -- Marker đỏ (cooldown)
                DrawMarker(
                    1,
                    TOMTICH_POINT.x, TOMTICH_POINT.y, TOMTICH_POINT.z - 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    1.5, 1.5, 1.0,
                    255, 0, 0, 150,
                    false, true, 2, false, nil, nil, false
                )
                
                if distance < INTERACTION_DISTANCE then
                    local currentTime = GetGameTimer() / 1000
                    local timeSinceUsed = currentTime - tomtichState.lastUsed
                    local remainingTime = math.ceil(SPAWN_COOLDOWN - timeSinceUsed)
                    local minutes = math.floor(remainingTime / 60)
                    local seconds = remainingTime % 60
                    
                    DrawText3D(TOMTICH_POINT.x, TOMTICH_POINT.y, TOMTICH_POINT.z + 0.5, string.format("~r~Đang hồi: %dm %ds", minutes, seconds))
                end
            end
        end
        
        Citizen.Wait(sleep)
    end
end)

-- Thread hiển thị marker kho báu (Level 3 only)
Citizen.CreateThread(function()
    while true do
        local sleep = 500
        
        -- Bỏ check level để test - luôn hiển thị marker
        -- if playerLevel >= 3 then
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local treasureCoords = vector3(TREASURE_POINT.x, TREASURE_POINT.y, TREASURE_POINT.z)
        local distance = #(playerCoords - treasureCoords)
        
        if distance < 50.0 then
            sleep = 0
            
            if treasureState.available then
                -- Marker vàng (available)
                DrawMarker(
                    1,
                    TREASURE_POINT.x, TREASURE_POINT.y, TREASURE_POINT.z - 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    1.5, 1.5, 1.0,
                    255, 204, 0, 150,
                    false, true, 2, false, nil, nil, false
                )
                
                if distance < INTERACTION_DISTANCE then
                    DrawText3D(TREASURE_POINT.x, TREASURE_POINT.y, TREASURE_POINT.z + 0.5, "[~y~E~w~] Đào Kho Báu")
                    
                    if IsControlJustReleased(0, 38) then
                        OpenTreasureGame()
                    end
                end
            else
                -- Marker đỏ (cooldown)
                DrawMarker(
                    1,
                    TREASURE_POINT.x, TREASURE_POINT.y, TREASURE_POINT.z - 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    1.5, 1.5, 1.0,
                    255, 0, 0, 150,
                    false, true, 2, false, nil, nil, false
                )
                
                if distance < INTERACTION_DISTANCE then
                    local currentTime = GetGameTimer() / 1000
                    local timeSinceUsed = currentTime - treasureState.lastUsed
                    local remainingTime = math.ceil(SPAWN_COOLDOWN - timeSinceUsed)
                    local minutes = math.floor(remainingTime / 60)
                    local seconds = remainingTime % 60
                    
                    DrawText3D(TREASURE_POINT.x, TREASURE_POINT.y, TREASURE_POINT.z + 0.5, string.format("~r~Đang hồi: %dm %ds", minutes, seconds))
                end
            end
        end
        -- end -- Bỏ end này để luôn chạy
        
        Citizen.Wait(sleep)
    end
end)
