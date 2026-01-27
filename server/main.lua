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
    
    local gridSize = Config.Treasure.gridSize
    local treasureCount = Config.Treasure.treasureCount
    local minDistance = Config.Treasure.minDistance
    
    -- Generate treasure positions
    local treasurePositions = {}
    local maxAttempts = 100
    local attempts = 0
    
    while #treasurePositions < treasureCount and attempts < maxAttempts do
        attempts = attempts + 1
        local pos = math.random(0, (gridSize * gridSize) - 1)
        
        -- Check if position already exists
        local exists = false
        for _, p in ipairs(treasurePositions) do
            if p == pos then
                exists = true
                break
            end
        end
        
        if not exists then
            -- If this is the second treasure, check distance from first
            if #treasurePositions == 1 then
                local firstPos = treasurePositions[1]
                local row1 = math.floor(firstPos / gridSize)
                local col1 = firstPos % gridSize
                local row2 = math.floor(pos / gridSize)
                local col2 = pos % gridSize
                
                -- Manhattan distance
                local distance = math.abs(row1 - row2) + math.abs(col1 - col2)
                
                if distance >= minDistance then
                    table.insert(treasurePositions, pos)
                end
            else
                -- First treasure, just add it
                table.insert(treasurePositions, pos)
            end
        end
    end
    
    -- Fallback if couldn't find good positions
    if #treasurePositions < treasureCount then
        treasurePositions = {math.random(0, 11), math.random(13, 24)}
    end
    
    activeTreasureGames[src] = {
        active = true,
        treasures = treasurePositions,
        foundTreasures = {},
        attempts = Config.Treasure.initialAttempts,
        openedCells = {}
    }
    
    -- Send game data to client
    TriggerClientEvent('treasure:gameData', src, {
        attempts = Config.Treasure.initialAttempts
    })
end)

RegisterNetEvent('treasure:openCell')
AddEventHandler('treasure:openCell', function(cellIndex)
    local src = source
    local game = activeTreasureGames[src]
    
    if not game or not game.active then return end
    
    -- Check if already opened
    for _, opened in ipairs(game.openedCells) do
        if opened == cellIndex then
            return
        end
    end
    
    table.insert(game.openedCells, cellIndex)
    
    -- Check if treasure
    local isTreasure = false
    for _, treasurePos in ipairs(game.treasures) do
        if treasurePos == cellIndex then
            isTreasure = true
            table.insert(game.foundTreasures, cellIndex)
            game.attempts = game.attempts + 1 -- Bonus turn
            break
        end
    end
    
    if isTreasure then
        -- Found treasure
        TriggerClientEvent('treasure:cellResult', src, {
            cellIndex = cellIndex,
            isTreasure = true,
            attemptsLeft = game.attempts,
            foundCount = #game.foundTreasures
        })
        
        -- Check win condition
        if #game.foundTreasures >= Config.Treasure.treasureCount then
            -- WIN!
            TriggerClientEvent('treasure:gameEnd', src, {
                success = true,
                treasures = game.treasures
            })
            
            ox:AddItem(src, ITEMS.TREASURE, Config.Treasure.rewardAmount)           
            TriggerClientEvent('cautomtich:notification', src, ITEMS.TREASURE, "🎉 Chúc mừng! Bạn đã nhận được kho báu!")
            
            activeTreasureGames[src] = nil
        end
    else
        -- Not treasure - give hint
        game.attempts = game.attempts - 1
        
        local hint = generateHint(cellIndex, game.treasures, game.foundTreasures)
        
        TriggerClientEvent('treasure:cellResult', src, {
            cellIndex = cellIndex,
            isTreasure = false,
            hint = hint,
            attemptsLeft = game.attempts,
            foundCount = #game.foundTreasures
        })
        
        -- Check lose condition
        if game.attempts <= 0 and #game.foundTreasures < Config.Treasure.treasureCount then
            -- LOSE!
            TriggerClientEvent('treasure:gameEnd', src, {
                success = false,
                treasures = game.treasures
            })
            
            TriggerClientEvent('cautomtich:notification', src, nil, "😔 Hết lượt! Bạn chưa tìm đủ kho báu.")
            
            activeTreasureGames[src] = nil
        end
    end
end)

-- Generate smart hint
function generateHint(cellIndex, treasures, foundTreasures)
    local gridSize = Config.Treasure.gridSize
    
    -- Convert index to row, col
    local row = math.floor(cellIndex / gridSize)
    local col = cellIndex % gridSize
    
    -- Find closest unfound treasure
    local closestTreasure = nil
    local minDistance = 999
    
    for _, treasurePos in ipairs(treasures) do
        local alreadyFound = false
        for _, found in ipairs(foundTreasures) do
            if found == treasurePos then
                alreadyFound = true
                break
            end
        end
        
        if not alreadyFound then
            local tRow = math.floor(treasurePos / Config.Treasure.gridSize)
            local tCol = treasurePos % Config.Treasure.gridSize
            local distance = math.abs(row - tRow) + math.abs(col - tCol)
            
            if distance < minDistance then
                minDistance = distance
                closestTreasure = treasurePos
            end
        end
    end
    
    if not closestTreasure then
        return "Không còn kho báu nào!"
    end
    
    local tRow = math.floor(closestTreasure / Config.Treasure.gridSize)
    local tCol = closestTreasure % Config.Treasure.gridSize
    
    local rowDiff = tRow - row
    local colDiff = tCol - col
    
    -- Adjacent (ngang/dọc 1 ô) - Gần nhất
    if (math.abs(rowDiff) == 1 and colDiff == 0) or 
       (rowDiff == 0 and math.abs(colDiff) == 1) then
        return "🔥 Kho báu đã gần bạn lắm rồi!"
    end
    
    -- Diagonal (chéo 1 ô) - Gần
    if math.abs(rowDiff) == 1 and math.abs(colDiff) == 1 then
        return "🎯 Kho báu ở gần đây"
    end
    
    -- Far away - give general direction
    local directions = {}
    if rowDiff < 0 then table.insert(directions, "Trên") end
    if rowDiff > 0 then table.insert(directions, "Dưới") end
    if colDiff < 0 then table.insert(directions, "Trái") end
    if colDiff > 0 then table.insert(directions, "Phải") end
    
    return "📍 Xa – " .. table.concat(directions, "/")
end

RegisterNetEvent('treasure:close')
AddEventHandler('treasure:close', function()
    local src = source
    if activeTreasureGames[src] then
        activeTreasureGames[src] = nil
    end
end)
