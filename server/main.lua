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
    COMMON = "tomtich",         -- Tôm tích thường (50%)
    UNCOMMON = "tomtichxanh",  -- Tôm tích xanh (30%)
    RARE = "tomtichdo",        -- Tôm tích đỏ (15%)
    LEGENDARY = "tomtichhoangkim" -- Tôm tích hoàng kim (5%)
}

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
    activeTomTichGames[src] = {
        active = true
    }
end)

RegisterNetEvent('tomtich:attempt')
AddEventHandler('tomtich:attempt', function(success, itemCode)
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
