local ITEMS = Config.Items
local DATA = {}

lib.callback.register("f17_tomtit:sv:NangCapNghe", function(source)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return false end
    local cid = xPlayer.PlayerData.citizenid
    local namePlayer = Player(src).state.name
    
    local p = promise.new()
    
    MySQL.query("SELECT tomtit_lvl, tomtit_currentcount FROM f17_joblevel WHERE citizenid = ?", {cid}, function(result)
        if result and result[1] then
            local lvl = result[1].tomtit_lvl
            local count = result[1].tomtit_currentcount
            p:resolve({level = lvl, count = count})
        else
            p:resolve({level = 1, count = 0})
        end
    end)
    
    local data = Citizen.Await(p)
    local jobLevel = data.level
    local jobPoint = data.count

    if not jobLevel or not jobPoint then
        no:Notify(src, "[Tôm Tít] Dữ liệu nghề không tồn tại", "error", 5000)
        return false
    end
    
    local nextLevel = jobLevel + 1
    local levelConfig = Config.Levels['Level'..nextLevel]

    if not levelConfig then return false end
    if Player(src).state.level < levelConfig.NeedLevels then
        no:Notify(src, string.format("[Tôm Tít] Bạn chưa đủ level để nâng cấp nghề (Yêu cầu LV %s)", levelConfig.NeedLevels), "primary", 5000)
        return false
    end
    if jobPoint < levelConfig.JobPoint then
        no:Notify(src, "[Tôm Tít] Bạn chưa đủ điểm để nâng cấp nghề", "primary", 5000)
        return false
    end

    if nextLevel == 3 then exports['f17_leaderboard']:UpdateAchivement(src, 'leveljobactive', 1) end
    MySQL.update("UPDATE f17_joblevel SET tomtit_lvl = ?, tomtit_currentcount = 0 WHERE citizenid = ?", {nextLevel, cid})
    
    if DATA[cid] then
        DATA[cid].level = nextLevel
        DATA[cid].count = 0
    end
    
    no:Notify(src, string.format("Bạn đã hoàn thành nhiệm vụ nâng cấp TÔM TÍT %d", nextLevel), "success", 30000)
    TriggerEvent("qb-log:server:CreateLog", "nangcapnghe", string.format("%s HOÀN THÀNH NÂNG CẤP NGHỀ TÔM TÍT %d", cid, nextLevel), "green", string.format("Tên: **%s**\nID: %s\nLevel hiện tại: %s", namePlayer, src, Player(src).state.level))

    return true
end)



RegisterNetEvent('f17_tomtit:sv:DoJob', function()
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    local cid = xPlayer.PlayerData.citizenid

    MySQL.single("SELECT tomtit_lvl, tomtit_currentcount FROM f17_joblevel WHERE citizenid = ?", {cid}, function(result)
        local lvl = 1
        local count = 0
        
        if result then
            lvl = result.tomtit_lvl or 1
            count = result.tomtit_currentcount or 0
        else
            MySQL.insert("INSERT INTO f17_joblevel (citizenid) VALUES (?)", {cid})
        end
        
        if not DATA[cid] then DATA[cid] = {} end
        DATA[cid].level = lvl
        DATA[cid].count = count
    end)
end)



RegisterNetEvent('f17_tomtit:sv:checkCooldown')
AddEventHandler('f17_tomtit:sv:checkCooldown', function(lastPos)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    local cid = xPlayer.PlayerData.citizenid

    if not DATA[cid] then
        no:Notify(src, "⚠️ Hủy thao tác do lỗi đồng bộ!", 'error', 3000)
        return
    end

    local currentTime = os.time()
    if DATA[cid].timestamp and (currentTime - DATA[cid].timestamp) < 180 then
        no:Notify(src, "⚠️ Bạn đang thao tác quá nhanh (Chưa đủ 180s)!", 'error', 3000)
        return
    end

    local hasItem = false
    if ox:RemoveItem(src, 'daycautom', 1) then
        hasItem = true
    elseif ox:RemoveItem(src, 'daycautomkhoa', 1) then
        hasItem = true
    end

    if hasItem then
        DATA[cid].timestamp = currentTime
        TriggerClientEvent('f17_tomtit:cl:OpenTomTitGame', src, DATA[cid].level)
    else
        no:Notify(src, 'Bạn không có Dây câu tôm hoặc Dây câu khóa', 'error', 3000)
    end
end)

local playerTreasureHistory = {}
local function TryTriggerTreasure(src, cid, playerLevel)
    if playerLevel < Config.Treasure.minLevelRequired then return false end

    local currentTime = os.time()
    
    if not playerTreasureHistory[cid] then
        playerTreasureHistory[cid] = {}
    end
    
    local recentTreasures = {}
    for _, timestamp in ipairs(playerTreasureHistory[cid]) do
        if currentTime - timestamp < Config.Treasure.hourWindow then
            table.insert(recentTreasures, timestamp)
        end
    end
    playerTreasureHistory[cid] = recentTreasures
    
    local treasureCount = #playerTreasureHistory[cid]
    
    if treasureCount >= Config.Treasure.maxPerHour then
        return false
    end

    local treasureChance = math.random(1, 100)
    if treasureChance <= Config.Treasure.treasureChance then
        table.insert(playerTreasureHistory[cid], currentTime)
        
        SetTimeout(3000, function()
            TriggerClientEvent('f17_tomtit:cl:showTreasureAfterGame', src)
        end)
        return true
    end

    return false
end

local function calculate_TT(P)
    local base_xp = 4  -- XP cơ bản mỗi hành động
    local adjustment_factor = 1 + P / 100  -- Hệ số điều chỉnh XP dựa trên giá trị P
    local xp = base_xp * adjustment_factor  -- XP sau điều chỉnh
    local lower_xp = math.floor(xp)  -- Giá trị XP thấp hơn
    local higher_xp = lower_xp + 1  -- Giá trị XP cao hơn
    local prob_higher_xp = xp - lower_xp  -- Xác suất nhận XP cao hơn
    local rand = math.random()  -- Tạo số ngẫu nhiên
    local final_xp  -- Biến lưu XP cuối cùng
    if rand <= prob_higher_xp then
        final_xp = higher_xp
    else
        final_xp = lower_xp
    end
    -- Nhân đôi XP nếu sự kiện bắt đầu
    if Config.StartEvent then
        final_xp = final_xp * 2
    end
    return final_xp, P  -- Trả về XP và P
end

RegisterNetEvent('f17_tomtit:sv:reward')
AddEventHandler('f17_tomtit:sv:reward', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local playerLevel = (DATA[cid] and DATA[cid].level) or 1
    local isValidItem = false
    local rewardItem = ITEMS.TRASH.id
    
    if data.success then
        rewardItem = data.item
        local levelData = Config.Levels['Level'..playerLevel]
        if levelData and levelData.rates and levelData.rates[rewardItem] then
            if levelData.rates[rewardItem] > 0 then
                isValidItem = true
            end
        end
        
        if not isValidItem then
            no:Notify(src, "⚠️ Bạn đang hack! Item không hợp lệ với level hiện tại.", 'error', 5000)
            print(string.format("[CHEAT DETECTED] ID: %s Name: %s tried to spawn invalid item: %s at Level: %d", src, GetPlayerName(src), rewardItem, playerLevel))
            return
        end
    else
        rewardItem = ITEMS.TRASH.id
    end

    local item = rewardItem
    local finalSuccess = data.success
    local Levels = {
        Config.Levels.Level1,
        Config.Levels.Level2,
        Config.Levels.Level3,
    }
    local money, totalmoney, xp, P = 0, 0, 0, 0

    for i = #Levels, 1, -1 do
        if playerLevel >= i then
            money = Levels[i].Payout
            break
        end
    end

    local check = GlobalState.BDVL.vieclam.tomtit
    local moneyText, xpText
    if check then
        xp, P = calculate_TT(check.xp)
        if P > 0 then
            xpText = "+ ~g~$"..xp.." XP~s~ ~b~(+"..P.."% BDVL)~s~"
        elseif P < 0 then
            xpText = "+ ~g~$"..xp.." XP~s~ ~r~("..P.."% BDVL)~s~"
        else
            xpText = "+ ~g~"..xp.." XP nhân vật~s~"
        end
    end
    
    MySQL.update('UPDATE f17_joblevel SET tomtit_currentcount = tomtit_currentcount + 1, tomtit_totalcount = tomtit_totalcount + 1 WHERE citizenid = ?', {cid})

    local notifyText = "~y~[Tôm Tít]~w~ Bạn nhận được:"
    if moneyText then notifyText = notifyText.."\n"..moneyText end
    if xpText then notifyText = notifyText.."\n"..xpText end
    notifyText = notifyText.."\n+ ~g~1 điểm tích lũy Tôm Tít~s~"

    TriggerClientEvent('f17-level:client:AddPlayerXP', src, xp)
    local addItemSuccess = ox:AddItem(src, item, 1)
    if addItemSuccess then
        notifyText = notifyText.."\n+ ~g~1 "..ox:Items()[item].label.."~s~"
    end

    TriggerClientEvent("QBCore:Notify", src, notifyText, "success", 10000)

    local willShowTreasure = false
    if finalSuccess then
        willShowTreasure = TryTriggerTreasure(src, cid, playerLevel)
    end

    if not willShowTreasure then
        TriggerClientEvent('f17_tomtit:cl:closeUI', src)
    end
end)

local ActiveTreasures = {}

RegisterNetEvent('f17_tomtit:sv:RegisterTreasure')
AddEventHandler('f17_tomtit:sv:RegisterTreasure', function(netId)
    local src = source
    ActiveTreasures[src] = netId
end)

AddEventHandler('playerDropped', function()
    local src = source
    if ActiveTreasures[src] then
        local entity = NetworkGetEntityFromNetworkId(ActiveTreasures[src])
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
        ActiveTreasures[src] = nil
    end
end)

RegisterNetEvent('treasure:finishGame')
AddEventHandler('treasure:finishGame', function(success, clientItem)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid

    -- if not playerTreasureHistory[cid] or #playerTreasureHistory[cid] == 0 then
    --     TriggerClientEvent("QBCore:Notify", src, "Bạn chưa tìm thấy kho báu nào gần đây!", "error", 5000)
    --     return
    -- end
    
    if success then
        local validItems = {
            ['ngoctraitrang'] = true,
            ['ngoctraiden'] = true
        }
        
        local rewardItem = clientItem
        
        if not validItems[rewardItem] then
            print(string.format("[Treasure] Invalid item from client: %s (ID: %s)", tostring(rewardItem), src))
            rewardItem = "ngoctraitrang"
        end
        
        local addItemSuccess = ox:AddItem(src, rewardItem, 1)
        
        if not addItemSuccess then
            no:Notify(src, 'Túi đồ đã đầy!', 'error', 5000)
        end
    end
end)