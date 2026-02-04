local inZoneTomTit = false
local onJobTomTit = false
local checkSpawn = false
local clCooldown = 0
local timeCooldown = 180000
local lastSuccessTime = 0
local lastPosition = nil
local maxDistance = 5.0
local isWorking = false
local isTreasureActive = false
local treasureObj = nil

-- Zone
ZoneTomTit = lib.zones.poly({
    points = {
        vec3(-264.81, 6510.32, 1.66),
        vec3(-317.49, 6547.39, 1.66),
        vec3(-276.09, 6603.08, 1.66),
        vec3(-226.06, 6560.96, 1.66)
    },
    thickness = 10.0,
    debug = false,
    onEnter = function()
        inZoneTomTit = true
        no:Notify("Bạn đã vào khu vực câu tôm tít", "success", 5000)
        if onJobTomTit then
            lib.showTextUI('showTextUI', {position = 'bottom-center', icon = 'fa-solid fa-shrimp', iconColor = 'white', style = { borderRadius = 5, backgroundColor = 'rgba(0, 0, 0, 0.8)', color = 'white' }})
        end
    end,
    inside = function()
        if onJobTomTit and not isWorking then
            if IsControlJustPressed(0, 38) then
                TriggerEvent("f17_tomtit:cl:Start")
            end
        end
    end,
    onExit = function()
        if inZoneTomTit then
            no:Notify("Bạn đã rời khỏi khu vực câu tôm tít!", "error", 1500)
        end
        inZoneTomTit = false
        lib.hideTextUI()
    end
})

--Function
local function StopTomTit()
	checkSpawn = false
	onJobTomTit = false
	TriggerServerEvent("f17-core:server:KetThucLamViec")
    no:Notify("Bạn đã kết thúc công việc thành công!", "error", 5000)
    lib.hideTextUI()
end

function OpenTreasureGame(skipCooldown)
    -- if not onJobTomTit or isTreasureActive then return end
    isTreasureActive = true

    local treasureConfig = {
        NUI = {
            Sounds = Config.NUI.Sounds,
            Treasure = Config.Treasure
        }
    }

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "showTreasure",
        config = treasureConfig,
        data = {
            attempts = Config.Treasure.initialAttempts
        }
    })
end

function CloseTreasureGame()
    isTreasureActive = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "hideTreasure"
    })
end

local function playAnimation()
    local ped = PlayerPedId()
    lib.requestAnimDict("amb@world_human_gardener_plant@male@base")
    TaskPlayAnim(ped, "amb@world_human_gardener_plant@male@base", "base", 8.0, -8.0, -1, 1, 0, false, false, false)

end

local function stopAnimation()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
end

function CloseTomTitGame()
    isWorking = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "hideTomTit"
    })

    stopAnimation()
end

--Callback
RegisterNUICallback('closeTomTit', function(data, cb)
    CloseTomTitGame()
    cb('ok')
end)

RegisterNUICallback('tomtitReward', function(data, cb)
    print('tomtitReward', json.encode(data))
    TriggerServerEvent('f17_tomtit:sv:reward', data)
    cb('ok')
end)

RegisterNUICallback('closeTreasure', function(data, cb)
    CloseTreasureGame()
    cb('ok')
end)

RegisterNUICallback('treasureFinish', function(data, cb)
    TriggerServerEvent('treasure:finishGame', data.success, data.item)
    cb('ok')
end)

--Event
RegisterNetEvent("f17_tomtit:cl:OpenJobsMenu", function()
    local dlv = QBCore.Functions.GetPlayerData().metadata.danglamviec
	if dlv == "none" or dlv == "Tôm Tít" then
		TriggerEvent("f17-jobs:cl:OpenJobsMenu", "tomtit")
	else
		no:Notify("Bạn đang làm việc "..dlv..", vui lòng kết thúc công việc trước khi tương tác nghề mới!", "error", 5000)
	end
end)

RegisterNetEvent("f17_tomtit:cl:DoJob", function(cb)
	if onJobTomTit then
		no:Notify("Bạn đang làm việc, không thể nhận việc!", "primary", 5000)
		cb(false)
		return
	end
	
	if IsRestrictedJob(PlayerJob.name) then
		no:Notify("Bạn đang là người ban ngành, không thể nhận việc!", "error", 5000)
        cb(false)
		return
    end
    
    if Player(GetPlayerServerId(PlayerId())).state.level < Config.Level then
		no:Notify("Bạn chưa đủ level để nhận việc! Yêu cầu level: "..Config.Level, "error", 5000)
        cb(false)
		return
    end

    TriggerServerEvent('f17_tomtit:sv:DoJob')
	TriggerServerEvent("f17-core:server:BatDauLamViec", "Tôm Tít")
	onJobTomTit = true
	no:Notify("Bạn đã bắt đầu công việc Câu Tôm Tít, hãy sử dụng 'Dây câu tôm' để bắt đầu làm việc!", "success", 10000)
    if inZoneTomTit then
        lib.showTextUI('[E] Đào cát tìm tôm', {position = 'bottom-center', icon = 'fa-solid fa-shrimp', iconColor = 'white', style = { borderRadius = 5, backgroundColor = 'rgba(0, 0, 0, 0.8)', color = 'white' }})
    end
	cb(true)
end)

RegisterNetEvent("f17_tomtit:cl:CancelJob", function()
	StopTomTit()
end)

RegisterNetEvent("f17_tomtit:cl:NangCapNghe", function(cb)
	local result = lib.callback.await("f17_tomtit:sv:NangCapNghe", false)
	cb(result)
end)

RegisterNetEvent("f17_tomtit:cl:Start")
AddEventHandler("f17_tomtit:cl:Start", function()
	if not onJobTomTit then
		no:Notify("Bạn chưa bắt đầu công việc Câu Tôm Tít, hãy tương tác NPC Tôm Tít!", "error", 5000)
		return
	end

    if not inZoneTomTit then
        no:Notify("Bạn không ở trong khu vực đào cát", "error", 5000)
        return
    end

	if checkSpawn then
        no:Notify("Bạn đang thao tác quá nhanh, có lẽ bạn nên sống chậm lại", "primary", 3000)
        return
    end
 
    if IsRestrictedJob(PlayerJob.name) then
        no:Notify("Bạn đang là người ban ngành, không thể nhận việc!", "error", 5000)
        return
    end

    OpenTomTitGame()
end)

local levelCache = {}

local function GetMinimizedConfig(level)
    if levelCache[level] then
        return levelCache[level]
    end

    local filteredConfig = {}
    
    filteredConfig.NUI = Config.NUI
    filteredConfig.ShrimpList = {}
    
    local currentLevelData = Config.Levels['Level'..level]
    if currentLevelData and currentLevelData.rates then
        for itemId, rate in pairs(currentLevelData.rates) do
            if rate > 0 then
                local itemInfo = nil
                for _, data in pairs(Config.Items) do
                    if data.id == itemId then
                        itemInfo = data
                        break
                    end
                end
                
                if itemInfo then
                    table.insert(filteredConfig.ShrimpList, {
                        id = itemInfo.id,
                        name = itemInfo.name,
                        image = itemInfo.image,
                        chance = rate
                    })
                end
            end
        end
    end
    
    levelCache[level] = filteredConfig
    return filteredConfig
end

RegisterNetEvent('f17_tomtit:cl:OpenTomTitGame')
AddEventHandler('f17_tomtit:cl:OpenTomTitGame', function(svLevel)
    SetNuiFocus(true, true)
    local minConfig = GetMinimizedConfig(svLevel)
    SendNUIMessage({
        action = "showTomTit",
        config = minConfig,
        level = svLevel,
    })
end)

function OpenTomTitGame()
    -- if not onJobTomTit or isWorking then return end
    isWorking = true
    
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local startTime = GetGameTimer()

    playAnimation()
    QBCore.Functions.Progressbar("digging_sand", "🏖️Đang đào cát tìm tôm", math.random(10000, 15000), false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        stopAnimation()

        if (startTime - lastSuccessTime) < timeCooldown then
            if lastPosition then
                local distance = #(coords - lastPosition)
                if distance < maxDistance then
                    no:Notify("Tôm chỗ này đã bị bắt mất rồi", 'error', 3000)
                else
                    no:Notify("Hình như chỗ này không có tôm. Hãy tìm chỗ khác xem sao", 'error', 3000)
                end
            else
                 no:Notify("Hình như chỗ này không có tôm. Hãy tìm chỗ khác xem sao", 'error', 3000)
            end
            
            isWorking = false
            return
        end
        
        lastPosition = coords
        lastSuccessTime = startTime
        
        TriggerServerEvent('f17_tomtit:sv:checkCooldown', lastPosition)
    end, function() -- Cancel
        stopAnimation()
        isWorking = false
        no:Notify("Đã hủy bỏ hành động..", 'error', 3000)
    end)
end

RegisterNetEvent('f17_tomtit:cl:closeUI')
AddEventHandler('f17_tomtit:cl:closeUI', function()
    SetTimeout(3000, function()
        CloseTomTitGame()
    end)
end)

RegisterNetEvent('f17_tomtit:cl:updateCooldown')
AddEventHandler('f17_tomtit:cl:updateCooldown', function(remainingMs)
    clCooldown = GetGameTimer() - (180000 - remainingMs)
end)


local function SpawnTreasureChest(coords)
    local model = `ws_premium_airdropdoom`
    lib.requestModel(model)

    local obj = CreateObject(model, coords.x, coords.y, coords.z, true, true, false) 
    if DoesEntityExist(obj) then
        treasureObj = obj
        local netId = ObjToNet(obj)
        TriggerServerEvent('f17_tomtit:sv:RegisterTreasure', netId)
    end
    SetEntityHeading(obj, 0.0)
    
    PlaceObjectOnGroundProperly(obj)
    local finalPos = GetEntityCoords(obj)
    
    local startZ = finalPos.z - 1.5
    SetEntityCoords(obj, finalPos.x, finalPos.y, startZ, 0.0, 0.0, 0.0, false)
    FreezeEntityPosition(obj, true)
    
    CreateThread(function()
        local currentZ = startZ
        while DoesEntityExist(obj) and currentZ < finalPos.z do
            currentZ = currentZ + 0.02
            if currentZ > finalPos.z then currentZ = finalPos.z end
            
            SetEntityCoords(obj, finalPos.x, finalPos.y, currentZ, 0.0, 0.0, 0.0, false)
            Wait(10)
        end
        if DoesEntityExist(obj) then
            PlaceObjectOnGroundProperly(obj)
        end
    end)

    CreateThread(function()
        local sleep = 1000
        while DoesEntityExist(obj) do
            local ped = PlayerPedId()
            local pCoords = GetEntityCoords(ped)
            local dist = #(pCoords - finalPos)

            if dist < 5.0 then
                sleep = 0
                DrawText3D(finalPos.x, finalPos.y, finalPos.z + 0.5, 'Ấn ~g~[E]~w~ để mở kho báu')
                if dist < 2.0 then
                    if IsControlJustPressed(0, 38) and not isTreasureActive then
                        NetworkRequestControlOfEntity(obj)
                        while not NetworkHasControlOfEntity(obj) do
                            Wait(10)
                        end
                        DeleteEntity(obj)
                        OpenTreasureGame(true)
                        break
                    end
                end
            end
            Wait(sleep)
        end
    end)
end

RegisterNetEvent('f17_tomtit:cl:showTreasureAfterGame')
AddEventHandler('f17_tomtit:cl:showTreasureAfterGame', function()
    CloseTomTitGame() 
    
    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)
    
    local offsetX = (math.random() * 4) - 2
    local offsetY = (math.random() * 4) - 2
    local spawnCoords = vector3(pCoords.x + offsetX, pCoords.y + offsetY, pCoords.z)
    
    no:Notify("🎉 Phát hiện Kho Báu gần đây! Hãy đào ngay!", 'success', 5000)
    SpawnTreasureChest(spawnCoords)
end)

-- Command test
RegisterCommand('tomtit', function()
    OpenTomTitGame()
end, false)

RegisterCommand('treasure', function()
    OpenTreasureGame(true)
end, false)

RegisterCommand('testtreasureevent', function()
    TriggerEvent('f17_tomtit:cl:showTreasureAfterGame')
end, false)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
      return
    end
    if treasureObj and DoesEntityExist(treasureObj) then
        DeleteEntity(treasureObj)
    end
    lib.hideTextUI()
end)