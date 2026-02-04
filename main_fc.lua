PlayerJob = {}
Blip = {}
loader = false

RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
	while not loader do Wait(200) end
    QBCore.Functions.GetPlayerData(function(PlayerData) PlayerJob = PlayerData.job end)
end)
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo
end)
AddEventHandler('onResourceStart', function(resource) if GetCurrentResourceName() ~= resource then return end
	while not loader do Wait(200) end
	QBCore.Functions.GetPlayerData(function(PlayerData) PlayerJob = PlayerData.job end)
end)