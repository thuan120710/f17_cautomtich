-- Lấy config từ file config.lua
local ITEMS = Config.Items
local LEVEL_CONFIG = Config.LevelConfig
local EXP_REWARDS = Config.ExpRewards

-- Hệ thống Level
local playerLevels = {} -- {[playerId] = level}
local playerExperience = {} -- {[playerId] = exp}

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

RegisterNetEvent('tomtich:startGame')
AddEventHandler('tomtich:startGame', function()
    local src = source
    
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
        startTime = os.time() -- 🔒 Lưu thời gian bắt đầu
    }
    
    -- Gửi thông tin level về client
    TriggerClientEvent('tomtich:updateLevel', src, level, exp)
end)

RegisterNetEvent('tomtich:attempt')
AddEventHandler('tomtich:attempt', function(success, itemCode, customMessage)
    local src = source
    
    print("🔍 [DEBUG] tomtich:attempt được gọi - Player: " .. src .. " | Success: " .. tostring(success))
    
    local game = activeTomTichGames[src]
    
    if not game or not game.active then 
        print("⚠️ [ANTI-CHEAT] Player " .. src .. " gửi kết quả không hợp lệ (game không tồn tại)")
        return 
    end
    
    -- 🔒 KIỂM TRA THỜI GIAN - Chống cheat (game tối thiểu theo config)
    local currentTime = os.time()
    local gameDuration = currentTime - game.startTime
    
    if gameDuration < Config.AntiSpam.minGameDuration then
        print("⚠️ [ANTI-CHEAT] Player " .. src .. " hoàn thành game quá nhanh (" .. gameDuration .. "s)")
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
        print("✅ [SERVER] Player " .. src .. " thành công - Tôm: " .. rewardItem)
    else
        print("❌ [SERVER] Player " .. src .. " thất bại")
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
        
        if leveledUp then
            -- Thông báo level up
            TriggerClientEvent('cautomtich:notification', src, nil, 
                string.format("🎉 LEVEL UP! Bạn đã đạt Level %d!", newLevel))
            
            -- Cập nhật level sau khi level up
            currentPlayerLevel = newLevel
        end
        
        -- Cập nhật level mới về client
        local currentExp = GetPlayerExp(src)
        local finalLevel = GetPlayerLevel(src)
        TriggerClientEvent('tomtich:updateLevel', src, finalLevel, currentExp)
    end
    
    -- Thêm item vào inventory
    print("🎁 [DEBUG] Đang thêm item: " .. item .. " cho player: " .. src)
    local addItemSuccess = ox:AddItem(src, item, 1)
    
    print("🎁 [DEBUG] AddItem result: " .. tostring(addItemSuccess))
    
    -- Gửi kết quả về client
    TriggerClientEvent('tomtich:gameResult', src, fishingSuccess, item)
    TriggerClientEvent('cautomtich:notification', src, item, reason)
    
    -- Kiểm tra level và câu thành công -> cơ hội hiển thị kho báu
    print("🔍 [DEBUG] Kiểm tra kho báu - FishingSuccess: " .. tostring(fishingSuccess) .. " | Level: " .. currentPlayerLevel)
    
    local willShowTreasure = false
    if fishingSuccess and currentPlayerLevel >= Config.Treasure.minLevelRequired then
        local treasureChance = math.random(1, 100)
        print("🎲 [DEBUG] Treasure chance roll: " .. treasureChance .. "/100")
        if treasureChance <= Config.Treasure.treasureChance then
            print("🎁 [DEBUG] ✅ Kích hoạt minigame kho báu cho player: " .. src)
            willShowTreasure = true
            -- Delay 3 giây để người chơi thấy kết quả câu tôm trước
            Citizen.SetTimeout(3000, function()
                print("🎁 [DEBUG] Gửi event showTreasureAfterGame đến player: " .. src)
                TriggerClientEvent('tomtich:showTreasureAfterGame', src)
            end)
        else
            print("🎲 [DEBUG] ❌ Không trúng kho báu lần này")
        end
    else
        print("🔍 [DEBUG] Không đủ điều kiện kho báu (Success: " .. tostring(fishingSuccess) .. ", Level: " .. currentPlayerLevel .. ")")
    end
    
    -- Nếu không có kho báu, đóng UI sau 3 giây
    if not willShowTreasure then
        TriggerClientEvent('tomtich:closeUI', src)
    end
    
    -- Thông báo nếu túi đầy
    if not addItemSuccess then
        print('⚠️ [DEBUG] Không thể thêm item - Có thể túi đồ đầy hoặc lỗi ox_inventory')
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
            TriggerClientEvent('cautomtich:notification', src, ITEMS.TREASURE, "🎉 Chúc mừng! Bạn đã tìm được " .. Config.Treasure.treasureCount .. " kho báu!")
            
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
