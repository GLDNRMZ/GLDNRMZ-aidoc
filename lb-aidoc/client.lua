local QBCore = exports['qb-core']:GetCoreObject()

local Active = false
local veh = nil
local ped1 = nil
local ped2 = nil
local spam = true
local ANIM_DICT = "mini@cpr@char_a@cpr_str"
local REVIVE_TIME = Config.ReviveTime
local PRICE = Config.Price

function Notify(msg, state)
    QBCore.Functions.Notify(msg, state)
end

local lastDoctorTime = 0

RegisterCommand("localdoctor", function(source, args, raw)
    local playerData = QBCore.Functions.GetPlayerData()

    if not playerData.metadata["isdead"] and not playerData.metadata["inlaststand"] then
        Notify("This can only be used when dead", "error")
        return
    end

    if not spam then
        return
    end

    QBCore.Functions.TriggerCallback('lb:docOnline', function(EMSOnline, hasEnoughMoney)
        if EMSOnline <= Config.Doctor and hasEnoughMoney then
            SpawnVehicle(GetEntityCoords(PlayerPedId()))
            TriggerServerEvent('lb:charge')
            Notify("Medic is arriving")
            lastDoctorTime = GetGameTimer()
        elseif EMSOnline > Config.Doctor then
            Notify("There are too many medics online", "error")
        elseif not hasEnoughMoney then
            Notify("Not Enough Money", "error")
        else
            Notify("Wait Paramedic is on its Way", "primary")
        end
    end)
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)

        if lastDoctorTime > 0 and GetGameTimer() - lastDoctorTime >= 90000 then -- DO NOT LOWER UNLESS YOU LOWER LINE 168. This will TP to the vehicle as its driving away.
            local playerPed = PlayerPedId()
            local ld = GetEntityCoords(ped1)
            if DoesEntityExist(ped1) then
                SetEntityCoords(playerPed, ld.x + 1.0, ld.y + 1.0, ld.z, 0, 0, 0, 1)
                DoctorNPC()
            end
            lastDoctorTime = 0
        end
    end
end)

function SpawnVehicle(x, y, z)
    spam = false
    local vehhash = GetHashKey("ambulance")

    RequestModel(vehhash)
    RequestModel('s_m_m_paramedic_01')
    while not HasModelLoaded(vehhash) or not HasModelLoaded('s_m_m_paramedic_01') do
        Citizen.Wait(1)
    end

    local spawnRadius = 40
    local loc = GetEntityCoords(PlayerPedId())
    local found, spawnPos, spawnHeading = GetClosestVehicleNodeWithHeading(loc.x + math.random(-spawnRadius, spawnRadius), loc.y + math.random(-spawnRadius, spawnRadius), loc.z, 0, 3, 0)

    if DoesEntityExist(vehhash) then
        return
    end

    local docVeh = CreateVehicle(vehhash, spawnPos, spawnHeading, true, false)
    SetVehicleOnGroundProperly(docVeh)
    SetVehicleNumberPlateText(docVeh, "QUICKFIX")
    SetEntityAsMissionEntity(docVeh, true, true)
    SetVehicleEngineOn(docVeh, true, true, false)
    SetVehicleSiren(docVeh, true)

    local docPed = CreatePedInsideVehicle(docVeh, 26, GetHashKey('s_m_m_paramedic_01'), -1, true, false)
	local passengerPed = CreatePedInsideVehicle(docVeh, 26, GetHashKey('s_m_m_paramedic_01'), 0, true, false)
    docBlip = AddBlipForEntity(docVeh)
    SetBlipFlashes(docBlip, true)
    SetBlipColour(docBlip, 5)

    PlaySoundFrontend(-1, "Text_Arrive_Tone", "Phone_SoundSet_Default", 1)
    Wait(2000)

    local docDriver = GetPedInVehicleSeat(docVeh, -1)
    TaskVehicleDriveToCoord(docDriver, docVeh, loc.x, loc.y, loc.z, 20.0, 0, GetEntityModel(docVeh), 524863, 2.0)

    veh = docVeh
    ped1 = docPed
	ped2 = passengerPed
    Active = true
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(200)
        if Active then
            local playerPed = GetPlayerPed(-1)
            local loc = GetEntityCoords(playerPed)
            local lc = GetEntityCoords(veh)
            local ld = GetEntityCoords(ped1)
            local dist = Vdist(loc, lc)
            local dist1 = Vdist(loc, ld)
            if dist <= 10 then
                if Active then
                    TaskGoToCoordAnyMeans(ped1, loc.x, loc.y, loc.z, 3.0, 0, 0, 786603, 0xbf800000)
                end
                if dist1 <= 1.33 then 
                    Active = false
                    ClearPedTasksImmediately(ped1)
                    if IsPedInAnyVehicle(playerPed, false) then
                        local veh = GetVehiclePedIsIn(playerPed, false)
                        SetEntityCoords(playerPed, ld.x + 1.0, ld.y + 1.0, ld.z, 0, 0, 0, 1)
                        DoctorNPC()
                    else
                        DoctorNPC()
                    end
                    
                end
            end
        end
    end
end)

function DoctorNPC()
	RequestAnimDict(ANIM_DICT)
	while not HasAnimDictLoaded(ANIM_DICT) do
		Citizen.Wait(1000)
	end

	TaskPlayAnim(ped1, ANIM_DICT, "cpr_pumpchest", 1.0, 1.0, -1, 9, 1.0, 0, 0, 0)

	PlayAmbientSpeech1(ped1, "GENERIC_CURSE_HIGH", "SPEECH_PARAMS_FORCE", 3)
	Wait(2000)
	PlayAmbientSpeech1(ped2, "GENERIC_INSULT_HIGH", "SPEECH_PARAMS_FORCE", 3)

	QBCore.Functions.Progressbar("revive_doc", "HANG IN THERE BUDDY!!", REVIVE_TIME, false, false, {
		disableMovement = false,
		disableCarMovement = false,
		disableMouse = false,
		disableCombat = true,
	}, {}, {}, {}, function()
		ClearPedTasks(ped1)
		Citizen.Wait(500)
		TriggerEvent("hospital:client:Revive")
		StopScreenEffect('DeathFailOut')
		Notify("Here's a lollipop, you were charged: "..PRICE, "success")

		RemovePedElegantly(ped1)
		TaskEnterVehicle(ped1, veh, 0, 2, 3.0, 1, 0)
		TaskVehicleDriveWander(ped1, veh, 25.0, 524295)
		Wait(15000)
		DeleteEntity(veh)
		DeleteEntity(ped1)
		DeleteEntity(ped2)
		spam = true
	end)
end
