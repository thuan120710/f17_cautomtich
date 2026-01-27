-- Lấy config từ file config.lua
local ITEMS = Config.Items
local LEVEL_CONFIG = Config.LevelConfig
local EXP_REWARDS = Config.ExpRewards

-- Hệ thống Level
local playerLevels = {} -- {[playerId] = level}
local playerExperience = {} -- {[playerId] = exp}
local playerCooldownTimes = {} -- {[cid] = lastPlayTime} - Dùng CID để tránh reset khi outgame

-- Hàm lấy level của người chơi
local function GetPlayerLevel(playerId)
    if not playerLevels[playerId] then
        playerLevels[playerId] = 1
        playerExperience[playerId] = 0
    end
    return playerLevels[playerId]
end

-- Hàm lấy exp của người chơi
local function GetPlayerExp(playerId)
    if not playerExperience[playerId] then
        playerExperience[playerId] = 0
    end
    return playerExperience[playerId]
end

-- Hàm thêm exp và kiểm tra level up
local function AddExperience(playerId, exp)
    local currentExp = GetPlayerExp(playerId)
    local currentLevel = GetPlayerLevel(playerId)
    
    currentExp = currentExp + exp
    playerExperience[playerId] = currentExp
    
    -- Kiểm tra level up
    local nextLevel = currentLevel + 1
    if LEVEL_CONFIG[nextLevel] and currentExp >= LEVEL_CONFIG[nextLevel].expRequired then
        playerLevels[playerId] = nextLevel
        TriggerClientEvent('cautomtich:notification', playerId, nil, 
            string.format("🎉 LEVEL UP! Bạn đã đạt Level %d!", nextLevel))
        return true, nextLevel
    end
    
    return false, currentLevel
end

-- Hàm random tôm theo level
local function GetRandomShrimpByLevel(level)
    local rates = LEVEL_CONFIG[level].rates
    local rand = math.random(1, 100)
    local cumulative = 0
    
    for item, chance in pairs(rates) do
        cumulative = cumulative + chance
        if rand <= cumulative then
            return item
        end
    end
    
    return ITEMS.COMMON -- Fallback
end

-- ============================================
-- MINIGAME TÔM TÍCH
-- ============================================

local activeTomTichGames = {}
local playerCooldowns = {} -- Anti-spam
local playerTreasureHistory = {} -- Lưu lịch sử xuất hiện kho báu {[playerId] = {timestamp1, timestamp2, ...}}

RegisterNetEvent('tomtich:startGame')
AddEventHandler('tomtich:startGame', function()
    local src = source
    
    -- Lấy CID của người chơi
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local cid = Player.PlayerData.citizenid
    local currentTime = os.time()
    
    -- Kiểm tra cooldown dựa trên CID (tránh reset khi outgame)
    if playerCooldownTimes[cid] and currentTime - playerCooldownTimes[cid] < 180 then
        local remainingTime = 180 - (currentTime - playerCooldownTimes[cid])
        local minutes = math.floor(remainingTime / 60)
        local seconds = remainingTime % 60
        TriggerClientEvent('cautomtich:notification', src, nil, string.format("⏱️ Khu vực này không thấy tôm", minutes, seconds))
        return
    end
    
    -- 🔒 RATE LIMITING - Chống spam
    if playerCooldowns[src] and os.time() - playerCooldowns[src] < Config.AntiSpam.cooldown then
        TriggerClientEvent('cautomtich:notification', src, nil, "⏱️ Chờ " .. Config.AntiSpam.cooldown .. " giây trước khi chơi lại!")
        return
    end
    
    playerCooldowns[src] = os.time()
    
    local level = GetPlayerLevel(src)
    local exp = GetPlayerExp(src)
    
    activeTomTichGames[src] = {
        active = true,
        level = level,
        startTime = os.time(), -- 🔒 Lưu thời gian bắt đầu
        cid = cid -- Lưu CID
    }
    
    -- Gửi thông tin level về client
    TriggerClientEvent('tomtich:updateLevel', src, level, exp)
end)

RegisterNetEvent('tomtich:attempt')
AddEventHandler('tomtich:attempt', function(success, itemCode, customMessage)
    local src = source
    
    local game = activeTomTichGames[src]
    
    if not game or not game.active then 
        return 
    end
    
    -- 🔒 KIỂM TRA THỜI GIAN - Chống cheat (game tối thiểu theo config)
    local currentTime = os.time()
    local gameDuration = currentTime - game.startTime
    
    if gameDuration < Config.AntiSpam.minGameDuration then
        TriggerClientEvent('cautomtich:notification', src, nil, "⚠️ Phát hiện hành vi bất thường!")
        activeTomTichGames[src] = nil
        return
    end
    
    game.active = false
    
    -- 🔒 SERVER TỰ RANDOM TÔM - KHÔNG TIN CLIENT
    local rewardItem = ITEMS.TRASH
    if success then
        -- Server tự random dựa trên level, KHÔNG dùng itemCode từ client
        rewardItem = GetRandomShrimpByLevel(game.level)
    end

    local item = success and rewardItem or ITEMS.TRASH
    local reason = success and "tomtich_success" or "tomtich_fail"
    
    -- Lưu trạng thái câu thành công và level hiện tại TRƯỚC KHI thêm EXP
    local fishingSuccess = success
    local currentPlayerLevel = game.level
    
    -- Thêm EXP nếu thành công
    if fishingSuccess and rewardItem ~= ITEMS.TRASH then
        local expGained = EXP_REWARDS[rewardItem] or 0
        local leveledUp, newLevel = AddExperience(src, expGained)
        
        -- Cập nhật level sau khi level up (không cần thông báo ở đây vì đã có trong AddExperience)
        if leveledUp then
            currentPlayerLevel = newLevel
        end
        
        -- Cập nhật level mới về client
        local currentExp = GetPlayerExp(src)
        local finalLevel = GetPlayerLevel(src)
        TriggerClientEvent('tomtich:updateLevel', src, finalLevel, currentExp)
    end
    
    -- Lưu cooldown time theo CID
    if game.cid then
        playerCooldownTimes[game.cid] = os.time()
    end
    
    -- Thêm item vào inventory
    local addItemSuccess = ox:AddItem(src, item, 1)
    
    -- Gửi kết quả về client
    TriggerClientEvent('tomtich:gameResult', src, fishingSuccess, item)
    TriggerClientEvent('cautomtich:notification', src, item, reason)
    
    -- Kiểm tra level và câu thành công -> cơ hội hiển thị kho báu
    local willShowTreasure = false
    if fishingSuccess and currentPlayerLevel >= Config.Treasure.minLevelRequired then
        -- Kiểm tra giới hạn 2 rương/giờ
        local currentTime = os.time()
        if not playerTreasureHistory[src] then
            playerTreasureHistory[src] = {}
        end
        
        -- Lọc bỏ các lần xuất hiện kho báu cũ hơn 1 giờ
        local recentTreasures = {}
        for _, timestamp in ipairs(playerTreasureHistory[src]) do
            if currentTime - timestamp < Config.Treasure.hourWindow then
                table.insert(recentTreasures, timestamp)
            end
        end
        playerTreasureHistory[src] = recentTreasures
        
        -- Kiểm tra số lượng kho báu trong 1 giờ qua
        local treasureCount = #playerTreasureHistory[src]
        
        if treasureCount >= Config.Treasure.maxPerHour then
            -- Đã đạt giới hạn
        else
            local treasureChance = math.random(1, 100)
            if treasureChance <= Config.Treasure.treasureChance then
                willShowTreasure = true
                
                -- Lưu timestamp xuất hiện kho báu
                table.insert(playerTreasureHistory[src], currentTime)
                
                -- Delay 3 giây để người chơi thấy kết quả câu tôm trước
                Citizen.SetTimeout(3000, function()
                    TriggerClientEvent('tomtich:showTreasureAfterGame', src)
                end)
            end
        end
    end
    
    -- Nếu không có kho báu, đóng UI sau 3 giây
    if not willShowTreasure then
        TriggerClientEvent('tomtich:closeUI', src)
    end
    
    -- Thông báo nếu túi đầy
    if not addItemSuccess then
        TriggerClientEvent('cautomtich:notification', src, nil, "⚠️ Không thể nhận vật phẩm!")
    end
    
    activeTomTichGames[src] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    if activeTomTichGames[src] then
        activeTomTichGames[src] = nil
    end
end)

-- ============================================
-- MINIGAME KHO BÁU (TREASURE HUNT)
-- ============================================

local activeTreasureGames = {}

RegisterNetEvent('treasure:startGame')
AddEventHandler('treasure:startGame', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    activeTreasureGames[src] = {
        active = true,
        startTime = os.time(),
        cid = Player.PlayerData.citizenid
    }
    
    -- Send initial state to client
    TriggerClientEvent('treasure:gameData', src, {
        attempts = Config.Treasure.initialAttempts
    })
end)

RegisterNetEvent('treasure:finishGame')
AddEventHandler('treasure:finishGame', function(success)
    local src = source
    local game = activeTreasureGames[src]
    
    if not game or not game.active then return end
    
    -- Basic validation: check duration
    local duration = os.time() - game.startTime
    if duration < 5 then -- Too fast for a 5x5 grid search
        TriggerClientEvent('cautomtich:notification', src, nil, "⚠️ Phát hiện hành vi bất thường!")
        activeTreasureGames[src] = nil
        return
    end
    
    game.active = false
    
    if success then
        -- Grant reward
        ox:AddItem(src, ITEMS.TREASURE, Config.Treasure.rewardAmount)           
        TriggerClientEvent('cautomtich:notification', src, ITEMS.TREASURE, "🎉 Chúc mừng! Bạn đã nhận được kho báu!")
        
        -- Optional: Add EXP if defined
        if Config.ExpRewards[ITEMS.TREASURE] then
            AddExperience(src, Config.ExpRewards[ITEMS.TREASURE])
        end
    end
    
    activeTreasureGames[src] = nil
end)

RegisterNetEvent('treasure:close')
AddEventHandler('treasure:close', function()
    local src = source
    if activeTreasureGames[src] then
        activeTreasureGames[src] = nil
    end
end)
