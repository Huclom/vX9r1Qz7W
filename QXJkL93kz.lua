-- =================================================================
-- --- SCRIPT MAESTRO (V6.2): "PARALLEL REPAIR FIX" ---
-- --- FIX: Restaura la reparación simultánea de múltiples piezas ---
-- =================================================================

-- >>> SISTEMA ANTI-OVERLAP <<<
if getgenv().MechanicFarmRunning then
    getgenv().MechanicFarmRunning = false
    task.wait(1)
end
getgenv().MechanicFarmRunning = true

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "FIX IT UP | Auto-Farm V6.2",
   LoadingTitle = "Modo Paralelo Activado...",
   LoadingSubtitle = "Rev Seba",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "MechanicFarmConfig",
      FileName = "ManagerV62"
   },
   Discord = { Enabled = false, Invite = "noinvitelink", RememberJoins = true },
   KeySystem = false,
})

-- =================================================================
-- VARIABLES
-- =================================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager") 
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 30)
local playerData = player:WaitForChild("PlayerData", 30)
local camera = Workspace.CurrentCamera

-- Variables de Estado
local currentMode = "OFF"
local isAutoBuyCarBuying = false 
local autoBuyCarQueue = {} 
local isRepairRunning = false 
local FAIL_DELAY = 5 
local CLEAN_DELAY = 10 
local VIP_THRESHOLD = 10 

local VENDEDOR_CFRAME = CFrame.new(-1903.80859, 4.57728004, -779.534912, 0.00912900362, -6.48468301e-08, 0.999958336, 1.85525124e-08, 1, 6.46801581e-08, -0.999958336, 1.79612734e-08, 0.00912900362)
local AUTOS_PARA_VENDER = {
    "Merquis C203", "Missah 750x", "Matsu Lanca", "Lokswag Golo GT", "BNV K5 e39",
    "Four Traffic", "Lokswag Golo MK5", "Toyoda Hellox", "Holde Inteiro",
    "Leskus not200", "BNV K3", "Missah Silva", "Siath Lion", "Fia-Te Ponto",
    "Peujo 200e6", "Ontel Costa", "Lokswag Golo", "Renas Kapturado", "Sacode Oitava",
    "Lokswag Passar", "Lokswag Golo MK4", "Auidy V4", "Holde Ciwiq", "BNV K3 e92", "Chule Camarao", "Auidy V5", 
    "Sabes Muito", "Xitro J3", "Toyoda Yapp"
}

-- Carga de Remotes
local RS_Events = ReplicatedStorage:WaitForChild("Events", 20)
if not RS_Events then Rayfield:Notify({Title = "Error", Content = "No se encontraron eventos.", Duration = 6.5, Image = 4483362458}) return end

local function getRemote(folder, name) if not folder then return nil end return folder:WaitForChild(name, 5) end

local remoteLoad = getRemote(RS_Events:WaitForChild("Vehicles", 10), "RemoteLoad")
local displayMessageEvent = getRemote(RS_Events, "DisplayMessage")
local NOTIFY_REMOTE = RS_Events:FindFirstChild("HUD") and RS_Events.HUD:FindFirstChild("Notifiy")
local setPaintEvent = RS_Events:FindFirstChild("Vehicles") and RS_Events.Vehicles:FindFirstChild("SetPaint")
local CONFIRM_REMOTE = RS_Events:FindFirstChild("HUD") and RS_Events.HUD:FindFirstChild("Confirmation")
local VEHICLES_FOLDER = Workspace:WaitForChild("Vehicles", 10)

if CONFIRM_REMOTE then CONFIRM_REMOTE.OnClientInvoke = function() return true end end

-- Declaraciones
local scanExistingCars
local startAutoSellLoop
local startAutoRepair

-- =================================================================
-- INTERFAZ
-- =================================================================
local TabFarm = Window:CreateTab("Auto Farm", 4483362458) 
local TabSettings = Window:CreateTab("Ajustes", 4483362458)
local TabManual = Window:CreateTab("Manual", 4483362458)

local StatusParagraph = TabFarm:CreateParagraph({Title = "Estado Actual", Content = "Esperando inicio..."})
local function updateStatus(text) StatusParagraph:Set({Title = "Estado Actual", Content = text}) end

local MainToggle = TabFarm:CreateToggle({
   Name = "Activar Auto-Farm (VIP)",
   CurrentValue = false,
   Flag = "FarmToggle", 
   Callback = function(Value)
        if Value then
            currentMode = "BUY"
            updateStatus("Iniciando escaneo...")
            task.spawn(scanExistingCars)
        else
            currentMode = "OFF"
            isAutoBuyCarBuying = false
            isRepairRunning = false
            autoBuyCarQueue = {}
            updateStatus("Sistema Apagado.")
        end
   end,
})

local VIPSlider = TabSettings:CreateSlider({
   Name = "Porcentaje VIP Máximo",
   Range = {0.1, 30},
   Increment = 1,
   Suffix = "%",
   CurrentValue = 10,
   Callback = function(Value) VIP_THRESHOLD = Value end,
})

local CleanDelaySlider = TabSettings:CreateSlider({
   Name = "Tiempo de Limpieza (Segundos)",
   Range = {0, 20},
   Increment = 1,
   Suffix = "s",
   CurrentValue = 10,
   Callback = function(Value) CLEAN_DELAY = Value end,
})

-- =================================================================
-- FUNCIONES AUXILIARES
-- =================================================================
local function clickGUIObject(guiObject)
    if not guiObject or not guiObject.Visible then return false end
    local absPos = guiObject.AbsolutePosition
    local absSize = guiObject.AbsoluteSize
    local centerX = absPos.X + (absSize.X / 2)
    local centerY = absPos.Y + (absSize.Y / 2)
    if centerX < 0 or centerY < 0 or centerX > camera.ViewportSize.X or centerY > camera.ViewportSize.Y then return false end
    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
    task.wait(0.1)
    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
    return true
end

local function findButtonGlobal(textToFind)
    for _, descendant in ipairs(playerGui:GetDescendants()) do
        if descendant:IsA("TextLabel") and descendant.Text:lower() == textToFind:lower() then
            local btn = descendant.Parent
            if btn and btn:IsA("GuiObject") then return btn end
        end
    end
    return nil
end

local function tryClickButtonByName(text)
    local btn = findButtonGlobal(text)
    if btn then return clickGUIObject(btn) end
    return false
end

TabManual:CreateButton({
   Name = "Limpiar Suelo",
   Callback = function() tryClickButtonByName("delete dropped parts") end,
})

-- =================================================================
-- REPARACIÓN V6.2 (PARALLEL RESTORED)
-- =================================================================
startAutoRepair = function() 
    if currentMode ~= "BUY" then return end
    local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    
    local targetCar = nil
    for i = 1, 10 do 
        if currentMode ~= "BUY" then return end 
        local closest = nil; local minDst = 20
        for _, car in ipairs(Workspace:WaitForChild("Vehicles"):GetChildren()) do
            if car:IsA("Model") and car:GetAttribute("Owner") == player.Name then
                local pivot = car:GetPivot().Position
                local dist = (rootPart.Position - pivot).Magnitude
                if dist < minDst then minDst = dist; closest = car end
            end
        end
        if closest then targetCar = closest; break end; task.wait(0.5)
    end
    if not targetCar then isRepairRunning = false; return end

    isRepairRunning = true 
    updateStatus("REPARANDO: Bloqueado en taller...")

    local carModel = targetCar 
    local machineMap = { ["Battery"]="BatteryCharger", ["AirIntake"]="PartsWasher", ["Radiator"]="PartsWasher", ["CylinderHead"]="GrindingMachine", ["EngineBlock"]="GrindingMachine", ["ExhaustManifold"] = "GrindingMachine", ["Suspension"]="GrindingMachine", ["Alternator"]="GrindingMachine", ["Transmission"]="GrindingMachine" }

    -- Ir al Pit
    local function getPitStop()
        local map = Workspace:WaitForChild("Map")
        local pitStopPosition = Vector3.new(-981.30127, 18.0568581, -129.036621)
        local closest = nil; local minDst = math.huge
        for _, child in ipairs(map:GetChildren()) do
            if child.Name == "PitStop Repair" then
                local d = (child:GetPivot().Position - pitStopPosition).Magnitude
                if d < minDst then minDst = d; closest = child end
            end
        end; return closest
    end
    
    local pitStop = getPitStop()
    if not pitStop then isRepairRunning = false; return end
    
    rootPart.CFrame = pitStop:GetPivot() * CFrame.new(0, 3, 5)
    task.wait(1) 

    local moveablePartsFolder = Workspace:WaitForChild("MoveableParts")
    if #moveablePartsFolder:GetChildren() > 0 then
        for i=1,3 do if tryClickButtonByName("bring dropped parts") then task.wait(1); break end; task.wait(0.5) end
        for i=1,5 do if tryClickButtonByName("delete dropped parts") then task.wait(2); break end; task.wait(0.5) end
    end
     
    -- Analizar Piezas
    local carPartsEvent = carModel:WaitForChild("PartsEvent", 10)
    local engineBay = carModel:FindFirstChild("Body", true) 
    if engineBay then engineBay = engineBay:FindFirstChild("EngineBay", true) or engineBay end
    local carValuesFolder = carModel:FindFirstChild("Values", true)
    if carValuesFolder then carValuesFolder = carValuesFolder:FindFirstChild("Engine", true) or carValuesFolder end
     
    if not carPartsEvent or not engineBay or not carValuesFolder then isRepairRunning = false; return end

    local allPartNames, partsToRepair_Names, partsToBuy_Data, droppedPartNameMap = {}, {}, {}, {}
    local engineType = carValuesFolder:FindFirstChild("EngineBlock") and carValuesFolder.EngineBlock.Value or ""

    for _, partModel in ipairs(engineBay:GetChildren()) do
        if partModel:IsA("Model") and partModel:FindFirstChild("Main") then
            local fullPartName = partModel.Name 
            local basePartName = fullPartName:gsub(engineType, ""):gsub("^-", ""):gsub("^_", ""):gsub("-$", ""):gsub("_$", "")
            local droppedName = basePartName 
            local valueObj = carValuesFolder:FindFirstChild(basePartName)
            if valueObj and valueObj:IsA("StringValue") then
                local splitVal = string.split(valueObj.Value, "|")
                if #splitVal >= 2 then droppedName = splitVal[2] end
            end
            droppedPartNameMap[fullPartName] = droppedName
            table.insert(allPartNames, fullPartName) 
            if machineMap[basePartName] or basePartName:find("Transmission") then
                table.insert(partsToRepair_Names, fullPartName)
            else
                local partString = "ENGINE|" .. engineType .. "|" .. droppedName
                table.insert(partsToBuy_Data, partString)
            end
        end
    end
     
    -- Desmontar
    for _, partName in ipairs(allPartNames) do 
        pcall(function() carPartsEvent:FireServer("RemovePart", partName) end)
        task.wait(0.1) 
    end
    task.wait(1.5); tryClickButtonByName("bring dropped parts"); task.wait(2)
     
    -- Comprar Paralelo
    local shopFolder = Workspace:WaitForChild("PartsStore"):WaitForChild("SpareParts"):WaitForChild("Parts")
    spawn(function()
        for _, partString in ipairs(partsToBuy_Data) do
            local split = string.split(partString, "|")
            local itemCD = shopFolder:FindFirstChild(split[2], true) and shopFolder:FindFirstChild(split[2], true):FindFirstChild(split[3], true) and shopFolder:FindFirstChild(split[2], true):FindFirstChild(split[3], true):FindFirstChild("ClickDetector", true)
            if itemCD then fireclickdetector(itemCD); task.wait(0.1) end -- Click rápido
        end
    end)

    -- Configurar Máquinas
    local machinePools = { BatteryCharger = {}, GrindingMachine = {}, PartsWasher = {} }
    local machineClickDetectors = {} 
    for _, machine in ipairs(pitStop:GetChildren()) do
        local cd = nil
        if machine.Name == "BatteryCharger" or machine.Name == "GrindingMachine" then
            cd = machine:FindFirstChild("Button", true) and machine:FindFirstChild("Button", true):FindFirstChild("ClickDetector")
        elseif machine.Name == "PartsWasher" then
            cd = machine:FindFirstChild("Faucet", true) and machine:FindFirstChild("Faucet", true):FindFirstChild("ClickDetector")
        end
        if cd and machinePools[machine.Name] then
            table.insert(machinePools[machine.Name], machine)
            machineClickDetectors[machine] = cd
        end
    end
    local machineIndexes = { BatteryCharger = 1, GrindingMachine = 1, PartsWasher = 1 }

    -- >>> REPARACIÓN PARALELA V6.2 (FIXED) <<<
    updateStatus("REPARANDO: Distribuyendo piezas a máquinas...")
    
    local partsBeingRepaired = {} 
    
    -- Fase 1: Distribuir todas las piezas simultáneamente
    for _, partSlotName in ipairs(partsToRepair_Names) do
        local targetDroppedName = droppedPartNameMap[partSlotName] or partSlotName
        local partObject = moveablePartsFolder:FindFirstChild(targetDroppedName)
        
        if partObject then
            local wear = partObject:GetAttribute("Wear") or 0
            if wear > 0 then
                local basePartName = partSlotName:gsub(engineType, ""):gsub("^-", ""):gsub("^_", ""):gsub("-$", ""):gsub("_$", "")
                if basePartName:find("Transmission") then basePartName = "Transmission" end
                local machineName = machineMap[basePartName]
                local pool = machinePools[machineName]
                
                if pool and #pool > 0 then
                    -- Rotación de máquinas para no saturar
                    local idx = machineIndexes[machineName]
                    local machine = pool[idx]
                    machineIndexes[machineName] = (idx % #pool) + 1 -- Siguiente máquina
                    
                    local detectorPad = machine:FindFirstChild("Detector", true)
                    
                    if detectorPad then
                        -- Enviar pieza a la máquina
                        partObject:PivotTo(detectorPad.CFrame * CFrame.new(0, 0.5, 0))
                        
                        -- Guardar en cola para monitorear
                        table.insert(partsBeingRepaired, { 
                            Part = partObject, 
                            Machine = machine, 
                            CD = machineClickDetectors[machine],
                            StartTime = os.clock()
                        })
                    end
                end
            end
        end
    end 
    
    -- Fase 2: Activar máquinas y esperar
    task.wait(0.5) -- Esperar que caigan las piezas
    for _, job in ipairs(partsBeingRepaired) do
        if job.CD then fireclickdetector(job.CD) end
    end
    
    -- Fase 3: Esperar a que terminen
    local repairTimeout = 0
    while #partsBeingRepaired > 0 and repairTimeout < 20 do
        task.wait(0.5)
        repairTimeout = repairTimeout + 0.5
        
        for i = #partsBeingRepaired, 1, -1 do
            local job = partsBeingRepaired[i]
            local wear = job.Part:GetAttribute("Wear") or 0
            
            if wear == 0 then
                -- Reparado
                table.remove(partsBeingRepaired, i)
            elseif (os.clock() - job.StartTime) > 8 then
                -- Se atascó, intentar clickear de nuevo
                job.StartTime = os.clock()
                if job.CD then fireclickdetector(job.CD) end
            end
        end
    end

    -- Ensamblar
    updateStatus("REPARANDO: Ensamblando...")
    for _, partSlotName in ipairs(allPartNames) do
        local targetDroppedName = droppedPartNameMap[partSlotName] or partSlotName
        local partToInstall = nil
        for _, p in ipairs(moveablePartsFolder:GetChildren()) do
            local wear = p:GetAttribute("Wear") or 0
            if wear == 0 and p.Name == targetDroppedName then
                partToInstall = p; break
            end
        end
        if partToInstall then
            pcall(function() carPartsEvent:FireServer("ReapplyPart", partToInstall, partSlotName) end)
            task.wait(0.15)
        end
    end

    local hoodCD = carModel:FindFirstChild("Misc", true) and carModel.Misc:FindFirstChild("Hood", true) and carModel.Misc.Hood:FindFirstChild("Detector", true) and carModel.Misc.Hood.Detector:FindFirstChild("ClickDetector")
    if hoodCD then fireclickdetector(hoodCD); task.wait(1) end
    
    -- >>> V6.1: TELETRANSFORTE DE PIE (SIN SENTARSE) <<<
    updateStatus("REPARANDO: Regresando al auto (DE PIE)...")
    
    local safePos = carModel:GetPivot() * CFrame.new(-6, 2, 0)
    rootPart.CFrame = safePos
    
    local arrived = false
    local attempts = 0
    repeat
        task.wait(0.2)
        attempts = attempts + 1
        local dist = (rootPart.Position - carModel:GetPivot().Position).Magnitude
        if dist < 15 then arrived = true end
        if attempts % 5 == 0 then rootPart.CFrame = safePos end
    until arrived or attempts > 20
    
    -- >>> SECCIÓN PINTURA <<<
    local paintArea = Workspace:WaitForChild("Map"):WaitForChild("pintamento"):WaitForChild("CarPaint")
    local paintPrompt = paintArea:FindFirstChild("Prompt", true) and paintArea:FindFirstChild("Prompt", true):FindFirstChild("ProximityPrompt")
    
    if paintPrompt and setPaintEvent then
        updateStatus("Finalizando (Pintura)...")
        fireproximityprompt(paintPrompt)
        task.wait(0.5) 
        
        pcall(function() 
            setPaintEvent:FireServer("Car", carModel, Color3.fromHSV(math.random(), 1, 1)) 
            print("🖌️ PINTADO. LIBERANDO CANDADO.")
        end)
        task.wait(2)
    end
     
    isRepairRunning = false 
    updateStatus("LIBRE: Buscando nuevos VIPs...")
end

-- =================================================================
-- LOGICA COMPRA (PROTEGIDA)
-- =================================================================
local function isCarInQueue(carModel)
    for _, item in ipairs(autoBuyCarQueue) do if item.car == carModel then return true end end
    return false
end

scanExistingCars = function()
    if currentMode ~= "BUY" then return end
    
    for _, carModel in ipairs(VEHICLES_FOLDER:GetChildren()) do
        if carModel:IsA("Model") and not isCarInQueue(carModel) then
            local cd = carModel:FindFirstChild("ClickDetector")
            if cd then 
                local percent = 100 
                local wearValue = carModel:GetAttribute("Wear")
                if wearValue then percent = wearValue * 100 end
                if percent <= VIP_THRESHOLD then
                    table.insert(autoBuyCarQueue, {car = carModel, percent = percent})
                end
            end
        end
    end
    updateStatus("Cola VIP: " .. #autoBuyCarQueue .. " autos")
end

spawn(function()
    while getgenv().MechanicFarmRunning do
        task.wait(1)
        
        if isRepairRunning then continue end
        
        if currentMode ~= "BUY" or #autoBuyCarQueue == 0 or isAutoBuyCarBuying then continue end

        isAutoBuyCarBuying = true
        
        table.sort(autoBuyCarQueue, function(a, b) return a.percent < b.percent end)
        local item = table.remove(autoBuyCarQueue, 1)
        local carToBuy = item.car
         
        if not carToBuy or not carToBuy.Parent then
            isAutoBuyCarBuying = false; if #autoBuyCarQueue == 0 then task.spawn(scanExistingCars) end; continue
        end

        updateStatus("Comprando VIP ("..item.percent.."%)...")
        
        if not isRepairRunning and tryClickButtonByName("delete dropped parts") then
            for k=1, 3 do task.wait(1) end 
        end
         
        if currentMode ~= "BUY" then isAutoBuyCarBuying = false; continue end

        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = carToBuy:GetPivot() * CFrame.new(-8, 0, 0)
            task.wait(0.5)
            fireclickdetector(carToBuy.ClickDetector)
            local _ = tryClickButtonByName("confirm") or tryClickButtonByName("yes") or tryClickButtonByName("buy")
            task.wait(1)
            
            local hoodPart = carToBuy:FindFirstChild("Misc") and carToBuy.Misc:FindFirstChild("Hood") and carToBuy.Misc.Hood:FindFirstChild("Detector") and carToBuy.Misc.Hood.Detector:FindFirstChild("ClickDetector")
            if hoodPart then fireclickdetector(hoodPart); task.wait(2) end
            
            if currentMode == "BUY" then startAutoRepair() end
        end
        
        isAutoBuyCarBuying = false
        if currentMode == "BUY" and #autoBuyCarQueue == 0 and not isRepairRunning then task.spawn(scanExistingCars) end
    end
end)

-- Eventos
if displayMessageEvent then
    displayMessageEvent.OnClientEvent:Connect(function(...)
        if currentMode ~= "BUY" then return end 
        local args = {...}; local text = args[2]
        if not text or type(text) ~= "string" then return end
        local percentStr = text:match("([%d%.]+)%%")
        if percentStr then
            local percent = tonumber(percentStr)
            if percent and percent <= VIP_THRESHOLD then
                task.wait(0.5)
                local children = VEHICLES_FOLDER:GetChildren()
                local lastCar = children[#children]
                if lastCar and not isCarInQueue(lastCar) then
                    Rayfield:Notify({Title = "VIP Nuevo", Content = "Auto: " .. percent .. "%", Duration = 3})
                    table.insert(autoBuyCarQueue, {car = lastCar, percent = percent})  
                end
            end
        end
    end)
end

Rayfield:Notify({Title = "V6.2 Final", Content = "Paralelo + No-Sit Activado.", Duration = 5})
