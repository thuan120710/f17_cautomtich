-- ============================================
-- SERVER LOGIC - Mini Game Câu Tôm Tích
-- ============================================

ESX = nil
QBCore = nil

local INVENTORY_TYPE = "OX_INVENTORY"

if INVENTORY_TYPE == "ESX" then
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
elseif INVENTORY_TYPE == "QBCORE" then
    QBCore = exports['qb-core']:GetCoreObject()
elseif INVENTORY_TYPE == "VRP" then
    local Proxy = module("vrp", "lib/Proxy")
    vRP = Proxy.getInterface("vRP")
end

local ITEMS = {
    TRASH = "racthainhua",
    COMMON = "tomtich",         -- Tôm tích thường
    UNCOMMON = "tomtichxanh",  -- Tôm tích xanh
    RARE = "tomtichdo",        -- Tôm tích đỏ
    LEGENDARY = "tomtichhoangkim", -- Tôm tích hoàng kim
    TREASURE = "khobau"        -- Kho báu (từ mini game)
}

-- Hệ thống Level
local playerLevels = {} -- {[playerId] = level}
local playerExperience = {} -- {[playerId] = exp}

-- Cấu hình Level
local LEVEL_CONFIG = {
    [1] = {
        expRequired = 0,
        rates = {
            [ITEMS.COMMON] = 60,
            [ITEMS.UNCOMMON] = 35,
            [ITEMS.RARE] = 5,
            [ITEMS.LEGENDARY] = 0,
            treasure = 0  -- Không có kho báu ở level 1
        }
    },
    [2] = {
        expRequired = 100, -- Cần 100 exp để lên level 2
        rates = {
            [ITEMS.COMMON] = 45,
            [ITEMS.UNCOMMON] = 40,
            [ITEMS.RARE] = 10,
            [ITEMS.LEGENDARY] = 5,
            treasure = 0  -- Không có kho báu ở level 2
        }
    },
    [3] = {
        expRequired = 300, -- Cần 300 exp để lên level 3
        rates = {
            [ITEMS.COMMON] = 40,
            [ITEMS.UNCOMMON] = 30,
            [ITEMS.RARE] = 15,
            [ITEMS.LEGENDARY] = 10,
            treasure = 5  -- 5% cơ hội kho báu ở level 3
        }
    }
}

-- Exp nhận được khi câu tôm
local EXP_REWARDS = {
    [ITEMS.COMMON] = 5,
    [ITEMS.UNCOMMON] = 10,
    [ITEMS.RARE] = 20,
    [ITEMS.LEGENDARY] = 50,
    [ITEMS.TREASURE] = 100
}

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

-- Helper function to give reward
function GiveReward(playerId, item, reason)
    if INVENTORY_TYPE == "ESX" then
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then xPlayer.addInventoryItem(item, 1) end
    elseif INVENTORY_TYPE == "QBCORE" then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            Player.Functions.AddItem(item, 1)
            TriggerClientEvent('inventory:client:ItemBox', playerId, QBCore.Shared.Items[item], "add")
        end
    elseif INVENTORY_TYPE == "VRP" then
        local user_id = vRP.getUserId({playerId})
        if user_id then vRP.giveInventoryItem({user_id, item, 1, true}) end
    elseif INVENTORY_TYPE == "OX_INVENTORY" then
        exports.ox_inventory:AddItem(playerId, item, 1)
    end
    
    TriggerClientEvent('cautomtich:notification', playerId, item, reason)
end

-- ============================================
-- MINIGAME TÔM TÍCH
-- ============================================

local TOMTICH_ITEM = "tomtich"
local activeTomTichGames = {}

RegisterNetEvent('tomtich:startGame')
AddEventHandler('tomtich:startGame', function()
    local src = source
    local level = GetPlayerLevel(src)
    local exp = GetPlayerExp(src)
    
    activeTomTichGames[src] = {
        active = true,
        level = level
    }
    
    -- Gửi thông tin level về client
    TriggerClientEvent('tomtich:updateLevel', src, level, exp)
end)

RegisterNetEvent('tomtich:attempt')
AddEventHandler('tomtich:attempt', function(success, itemCode, customMessage)
    local src = source
    local game = activeTomTichGames[src]
    
    if not game or not game.active then return end
    
    game.active = false
    
    -- Validate item (chống hack cơ bản, chỉ chấp nhận item trong whitelist nếu success)
    local rewardItem = ITEMS.TRASH
    if success then
        -- Client gửi item code lên, server check lại hoặc tin tưởng (ở mức cơ bản)
        -- Tốt nhất là client gửi loại (type) rồi server random, nhưng user yêu cầu logic "kéo lên thì hiện"
        -- Tạm thời tin tưởng client gửi đúng item code từ danh sách cho phép
        if itemCode == ITEMS.COMMON or itemCode == ITEMS.UNCOMMON or itemCode == ITEMS.RARE or itemCode == ITEMS.LEGENDARY then
            rewardItem = itemCode
        else
            rewardItem = ITEMS.COMMON -- Default fallback
        end
    end

    local item = success and rewardItem or ITEMS.TRASH
    local reason = success and "tomtich_success" or "tomtich_fail"
    
    -- Thêm EXP nếu thành công
    if success and rewardItem ~= ITEMS.TRASH then
        local expGained = EXP_REWARDS[rewardItem] or 0
        local leveledUp, newLevel = AddExperience(src, expGained)
        
        if leveledUp then
            -- Thông báo level up
            TriggerClientEvent('cautomtich:notification', src, nil, 
                string.format("🎉 LEVEL UP! Bạn đã đạt Level %d!", newLevel))
        end
        
        -- Cập nhật level mới về client
        local currentExp = GetPlayerExp(src)
        local currentLevel = GetPlayerLevel(src)
        TriggerClientEvent('tomtich:updateLevel', src, currentLevel, currentExp)
    end
    
    -- Thêm item vào inventory
    if INVENTORY_TYPE == "ESX" then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then xPlayer.addInventoryItem(item, 1) end
    elseif INVENTORY_TYPE == "QBCORE" then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            Player.Functions.AddItem(item, 1)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], "add")
        end
    elseif INVENTORY_TYPE == "VRP" then
        local user_id = vRP.getUserId({src})
        if user_id then vRP.giveInventoryItem({user_id, item, 1, true}) end
    elseif INVENTORY_TYPE == "OX_INVENTORY" then
        exports.ox_inventory:AddItem(src, item, 1)
    end
    
    -- Gửi kết quả về client
    TriggerClientEvent('tomtich:gameResult', src, success, item)
    
    -- Notification
    -- Note: reusing 'caongheu:notification' event name since client logic expects it,
    -- or we can rename it later if we want total separation, but for 100% same operation, keeping it is fine.
    TriggerClientEvent('cautomtich:notification', src, item, reason)
    
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
    
    -- Generate treasure positions (2 treasures in 5x5 grid)
    local treasurePositions = {}
    while #treasurePositions < 2 do
        local pos = math.random(0, 24) -- 0-24 for 5x5 grid
        local exists = false
        for _, p in ipairs(treasurePositions) do
            if p == pos then
                exists = true
                break
            end
        end
        if not exists then
            table.insert(treasurePositions, pos)
        end
    end
    
    activeTreasureGames[src] = {
        active = true,
        treasures = treasurePositions,
        foundTreasures = {},
        attempts = 5,
        openedCells = {}
    }
    
    -- Send game data to client
    TriggerClientEvent('treasure:gameData', src, {
        attempts = 5
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
        if #game.foundTreasures >= 2 then
            -- WIN!
            TriggerClientEvent('treasure:gameEnd', src, {
                success = true,
                treasures = game.treasures
            })
            
            -- Give rewards
            if INVENTORY_TYPE == "OX_INVENTORY" then
                exports.ox_inventory:AddItem(src, ITEMS.TREASURE, 2)
            end
            
            TriggerClientEvent('cautomtich:notification', src, ITEMS.TREASURE, "🎉 Chúc mừng! Bạn đã tìm được 2 kho báu!")
            
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
        if game.attempts <= 0 and #game.foundTreasures < 2 then
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
    -- Convert index to row, col
    local row = math.floor(cellIndex / 5)
    local col = cellIndex % 5
    
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
            local tRow = math.floor(treasurePos / 5)
            local tCol = treasurePos % 5
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
    
    local tRow = math.floor(closestTreasure / 5)
    local tCol = closestTreasure % 5
    
    local rowDiff = tRow - row
    local colDiff = tCol - col
    
    -- Diagonal neighbor (1 cell away diagonally)
    if math.abs(rowDiff) == 1 and math.abs(colDiff) == 1 then
        return "🔥 Kho báu đã gần bạn lắm rồi!"
    end
    
    -- Adjacent neighbor (1 cell away horizontally or vertically)
    if (math.abs(rowDiff) == 1 and colDiff == 0) or (rowDiff == 0 and math.abs(colDiff) == 1) then
        local direction = ""
        if rowDiff < 0 then direction = "Trên"
        elseif rowDiff > 0 then direction = "Dưới"
        elseif colDiff < 0 then direction = "Trái"
        elseif colDiff > 0 then direction = "Phải"
        end
        return "🎯 Kho báu hình như nằm gần phía " .. direction
    end
    
    -- Far away
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
