-- =================================================================
-- --- SCRIPT MAESTRO (V5.5): "REMOTE PAINT" ---
-- --- FIX: Pinta a distancia sin mover al personaje ("Car", Model, Color) ---
-- =================================================================

-- Cargar Rayfield Library
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "FIX IT UP! | Auto-Farm V5.5",
   LoadingTitle = "Optimización de Pintura...",
   LoadingSubtitle = "by RevSeba",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "MechanicFarmConfig",
      FileName = "ManagerV55"
   },
   Discord = {
      Enabled = false,
      Invite = "noinvitelink",
      RememberJoins = true 
   },
   KeySystem = false,
})

-- =================================================================
-- VARIABLES Y SERVICIOS
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
if not RS_Events then Rayfield:Notify({Title = "Error", Content = "No se encontraron eventos del juego.", Duration = 6.5, Image = 4483362458}) return end

local function getRemote(folder, name)
    if not folder then return nil end
    return folder:WaitForChild(name, 5)
end

local remoteLoad = getRemote(RS_Events:WaitForChild("Vehicles", 10), "RemoteLoad")
local displayMessageEvent = getRemote(RS_Events, "DisplayMessage")
local NOTIFY_REMOTE = RS_Events:FindFirstChild("HUD") and RS_Events.HUD:FindFirstChild("Notifiy")
local setPaintEvent = RS_Events:FindFirstChild("Vehicles") and RS_Events.Vehicles:FindFirstChild("SetPaint")

local CONFIRM_REMOTE = RS_Events:FindFirstChild("HUD") and RS_Events.HUD:FindFirstChild("Confirmation")
local VEHICLES_FOLDER = Workspace:WaitForChild("Vehicles", 10)

if CONFIRM_REMOTE then CONFIRM_REMOTE.OnClientInvoke = function() return true end end

-- DECLARACIONES ADELANTADAS
local scanExistingCars
local startAutoSellLoop
local startAutoRepair

-- =================================================================
-- INTERFAZ RAYFIELD
-- =================================================================
local TabFarm = Window:CreateTab("Auto Farm", 4483362458) 
local TabSettings = Window:CreateTab("Ajustes", 4483362458)
local TabManual = Window:CreateTab("Manual", 4483362458)

local StatusParagraph = TabFarm:CreateParagraph({Title = "Estado Actual", Content = "Esperando inicio..."})

local function updateStatus(text)
    StatusParagraph:Set({Title = "Estado Actual", Content = text})
end

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
   Range = {1, 30},
   Increment = 1,
   Suffix = "%",
   CurrentValue = 10,
   Flag = "VIPSlider", 
   Callback = function(Value)
        VIP_THRESHOLD = Value
   end,
})

local CleanDelaySlider = TabSettings:CreateSlider({
   Name = "Tiempo de Limpieza (Segundos)",
   Range = {0, 20},
   Increment = 1,
   Suffix = "s",
   CurrentValue = 10,
   Flag = "CleanDelay", 
   Callback = function(Value)
        CLEAN_DELAY = Value
   end,
})

-- =================================================================
-- FUNCIONES AUXILIARES
-- =================================================================

local function clickGUIObject(guiObject)
    if not guiObject then return false end
    if not guiObject.Visible then return false end
     
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
   Callback = function()
        tryClickButtonByName("delete dropped parts")
   end,
})

-- =================================================================
-- LÓGICA DE VENTA
-- =================================================================
local function getSellPrompt()
    local map = Workspace:FindFirstChild("Map")
    local sellCar = map and map:FindFirstChild("SellCar")
    return sellCar and sellCar:FindFirstChildWhichIsA("ProximityPrompt", true)
end

startAutoSellLoop = function()
    updateStatus("Modo: VENDIENDO (Garaje Lleno)")
    local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local garageFolder = playerData:WaitForChild("Garage")
     
    rootPart.CFrame = VENDEDOR_CFRAME
    task.wait(2) 
     
    local promptVenta = getSellPrompt()
     
    for _, carData in ipairs(garageFolder:GetChildren()) do
        if currentMode ~= "SELL" then break end 
        local modelName = carData:FindFirstChild("Model") and carData.Model.Value
        if not modelName then continue end 

        if table.find(AUTOS_PARA_VENDER, modelName) then
            updateStatus("Vendiendo: " .. modelName)
            local carIDToSell = carData.Name
            local targetCFrame = rootPart.CFrame * CFrame.new(0, 3, 12)
             
            if (rootPart.Position - VENDEDOR_CFRAME.Position).Magnitude > 15 then
                rootPart.CFrame = VENDEDOR_CFRAME; task.wait(0.5)
            end
             
            pcall(function() remoteLoad:InvokeServer(carData, targetCFrame) end)
            local carInWorld = Workspace.Vehicles:WaitForChild(carIDToSell, 5)
             
            if carInWorld then
                carInWorld:PivotTo(targetCFrame)
                if setPaintEvent then
                   pcall(function() setPaintEvent:FireServer("Car", carInWorld, Color3.fromHSV(math.random(), 1, 1)) end)
                end
                task.wait(0.5)
                if promptVenta then pcall(fireproximityprompt, promptVenta, 0) end
                task.wait(2.5)
            end
        end
    end
    currentMode = "BUY"
    updateStatus("Venta finalizada. Volviendo a Farm.")
    Rayfield:Notify({Title = "Sistema", Content = "Venta completada. Buscando autos...", Duration = 5})
    task.spawn(scanExistingCars)
end

if NOTIFY_REMOTE then
    NOTIFY_REMOTE.OnClientEvent:Connect(function(text)
        if text == "Garage limit reached" then 
            Rayfield:Notify({Title = "Alerta", Content = "Garaje Lleno! Cambiando a modo venta.", Duration = 5})
            currentMode = "SELL"
            isRepairRunning = false 
            isAutoBuyCarBuying = false
            task.spawn(startAutoSellLoop)
        end
    end)
end

-- =================================================================
-- LÓGICA DE REPARACIÓN (V5.5 OPTIMIZADA)
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
    updateStatus("REPARANDO: Iniciando proceso...")

    local carModel = targetCar 
    local machineMap = { ["Battery"]="BatteryCharger", ["AirIntake"]="PartsWasher", ["Radiator"]="PartsWasher", ["CylinderHead"]="GrindingMachine", ["EngineBlock"]="GrindingMachine", ["ExhaustManifold"] = "GrindingMachine", ["Suspension"]="GrindingMachine", ["Alternator"]="GrindingMachine", ["Transmission"]="GrindingMachine" }

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
    task.wait(2) 

    local moveablePartsFolder = Workspace:WaitForChild("MoveableParts")
    if #moveablePartsFolder:GetChildren() > 0 then
        updateStatus("REPARANDO: Limpiando zona...")
        for i=1,3 do if tryClickButtonByName("bring dropped parts") then task.wait(1.5); break end; task.wait(0.5) end
        for i=1,5 do
            if tryClickButtonByName("delete dropped parts") then
                for j = 1, 8 do if #moveablePartsFolder:GetChildren() == 0 then break end; task.wait(1) end
                break
            end
            task.wait(0.5)
        end
    end
     
    updateStatus("REPARANDO: Analizando motor...")
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
     
    for _, partName in ipairs(allPartNames) do 
        if not isRepairRunning then break end
        pcall(function() carPartsEvent:FireServer("RemovePart", partName) end)
        task.wait(0.1) 
    end
    task.wait(1.5) 
    tryClickButtonByName("bring dropped parts")
    task.wait(2)
     
    local shopFolder = Workspace:WaitForChild("PartsStore"):WaitForChild("SpareParts"):WaitForChild("Parts")
    local function do_parallel_buy()
        for _, partString in ipairs(partsToBuy_Data) do
            if not isRepairRunning then break end
            local split = string.split(partString, "|")
            local itemCD = shopFolder:FindFirstChild(split[2], true) and shopFolder:FindFirstChild(split[2], true):FindFirstChild(split[3], true) and shopFolder:FindFirstChild(split[2], true):FindFirstChild(split[3], true):FindFirstChild("ClickDetector", true)
            if itemCD then fireclickdetector(itemCD); task.wait(0.5) end
        end
        return true
    end

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

    local function do_parallel_repair()
        local partsBeingRepaired = {} 
        for _, partSlotName in ipairs(partsToRepair_Names) do
            if not isRepairRunning then break end 
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
                        local idx = machineIndexes[machineName]
                        local machine = pool[idx]
                        if not machine then continue end
                        machineIndexes[machineName] = (idx % #pool) + 1
                         
                        local detectorPad = machine:FindFirstChild("Detector", true)
                        if detectorPad then
                            partObject:PivotTo(detectorPad.CFrame * CFrame.new(0, 0.5, 0))
                            task.wait(0.2)
                            fireclickdetector(machineClickDetectors[machine])
                            table.insert(partsBeingRepaired, { Part = partObject, StartTime = os.clock(), Machine = machine, CD = machineClickDetectors[machine] })
                        end
                    end
                end
            end
        end 

        while #partsBeingRepaired > 0 and isRepairRunning do 
            task.wait(0.5) 
            for i = #partsBeingRepaired, 1, -1 do 
                local data = partsBeingRepaired[i]
                if not data.Machine or not data.Part or not data.Part.Parent then table.remove(partsBeingRepaired, i); continue end
                local wear = data.Part:GetAttribute("Wear") or 0
                if wear == 0 then
                    table.remove(partsBeingRepaired, i)
                elseif (os.clock() - data.StartTime) > 20 then
                    data.StartTime = os.clock()
                    local detectorPad = data.Machine:FindFirstChild("Detector", true)
                    if detectorPad then
                        data.Part:PivotTo(detectorPad.CFrame * CFrame.new(0, 0.5, 0))
                        fireclickdetector(data.CD)
                    end
                end
            end 
        end 
        return true
    end

    local buy_done = false; local repair_done = false
    task.spawn(function() buy_done = do_parallel_buy() end)
    task.spawn(function() repair_done = do_parallel_repair() end)
    while not (buy_done and repair_done) and isRepairRunning do task.wait(0.5) end
    if not isRepairRunning then return end

    updateStatus("REPARANDO: Ensamblando...")
    for _, partSlotName in ipairs(allPartNames) do
        if not isRepairRunning then break end 
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
    
    -- >>> SECCIÓN DE PINTURA OPTIMIZADA (V5.5) <<<
    
    local paintArea = Workspace:WaitForChild("Map"):WaitForChild("pintamento"):WaitForChild("CarPaint")
    local paintPrompt = paintArea:FindFirstChild("Prompt", true) and paintArea:FindFirstChild("Prompt", true):FindFirstChild("ProximityPrompt")
    
    if paintPrompt and setPaintEvent then
        updateStatus("Pintando... (Remoto)")
        
        -- 1. Activamos Prompt a distancia (Sin teleport)
        fireproximityprompt(paintPrompt)
        task.wait(0.5) -- Espera técnica para que el servidor abra sesión
        
        -- 2. Buscamos el auto que está AL LADO NUESTRO (porque no nos movimos)
        local foundCar = nil
        local minPaintDist = 50 
        
        for _, c in pairs(VEHICLES_FOLDER:GetChildren()) do
            if c:IsA("Model") and (c:GetAttribute("Owner") == player.Name or c.Name == player.Name.."'s Car") then
                local refPart = c:FindFirstChild("DriveSeat") or c:FindFirstChildOfClass("BasePart", true)
                if refPart then
                     local dist = (rootPart.Position - refPart.Position).Magnitude
                     if dist < minPaintDist then
                         minPaintDist = dist
                         foundCar = c
                     end
                end
            end
        end
        
        if foundCar then
            pcall(function() 
                setPaintEvent:FireServer("Car", foundCar, Color3.fromHSV(math.random(), 1, 1)) 
                print("🖌️ PINTURA ÉXITO: Método 'Car' enviado.")
            end)
            Rayfield:Notify({Title = "Pintura", Content = "Auto pintado correctamente.", Duration = 3})
        else
            warn("No se encontró tu auto cerca para pintar.")
        end
        task.wait(2)
    end
     
    isRepairRunning = false
    updateStatus("REPARACIÓN COMPLETADA")
    Rayfield:Notify({Title = "Trabajo Terminado", Content = "Ciclo finalizado.", Duration = 3})
end

-- =================================================================
-- LÓGICA DE COMPRA ESCANEO (CORE)
-- =================================================================
local function isCarInQueue(carModel)
    for _, item in ipairs(autoBuyCarQueue) do if item.car == carModel then return true end end
    return false
end

scanExistingCars = function()
    if currentMode ~= "BUY" then return end
    updateStatus("Escaneando mapa por VIPs <" .. VIP_THRESHOLD .. "%")
    
    for _, carModel in ipairs(VEHICLES_FOLDER:GetChildren()) do
        if carModel:IsA("Model") and not isCarInQueue(carModel) then
            local cd = carModel:FindFirstChild("ClickDetector")
            if cd then 
                local percent = 100 
                local wearValue = carModel:GetAttribute("Wear")
                if wearValue then percent = math.floor(wearValue * 100) end
                
                if percent <= VIP_THRESHOLD then
                    table.insert(autoBuyCarQueue, {car = carModel, percent = percent})
                    Rayfield:Notify({Title = "VIP Encontrado", Content = "Auto detectado con " .. percent .. "%", Duration = 3})
                end
            end
        end
    end
    updateStatus("Cola VIP: " .. #autoBuyCarQueue .. " autos")
end

spawn(function()
    while true do
        task.wait(1)
        if isRepairRunning then continue end
        if currentMode ~= "BUY" or #autoBuyCarQueue == 0 or isAutoBuyCarBuying then continue end

        isAutoBuyCarBuying = true
        
        table.sort(autoBuyCarQueue, function(a, b) return a.percent < b.percent end)
        local item = table.remove(autoBuyCarQueue, 1)
        local carToBuy = item.car
         
        if not carToBuy or not carToBuy.Parent or not carToBuy:FindFirstChild("ClickDetector") then
            isAutoBuyCarBuying = false; if #autoBuyCarQueue == 0 then task.spawn(scanExistingCars) end; continue
        end

        updateStatus("Limpiando área ("..CLEAN_DELAY.."s)...")
        if tryClickButtonByName("delete dropped parts") then
            for k=1, CLEAN_DELAY do
                if currentMode ~= "BUY" then break end 
                task.wait(1)
            end
        end
         
        if currentMode ~= "BUY" then isAutoBuyCarBuying = false; continue end

        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = carToBuy:GetPivot() * CFrame.new(-8, 0, 0)
            updateStatus("Intentando comprar VIP ("..item.percent.."%)")
            task.wait(0.8)
             
            local purchaseSuccess = false
            for i = 1, 5 do
                if currentMode ~= "BUY" then break end
                if not carToBuy or not carToBuy.Parent then purchaseSuccess = true; break end
                 
                root.CFrame = carToBuy:GetPivot() * CFrame.new(-6, 0, 0)
                fireclickdetector(carToBuy.ClickDetector)
                local _ = tryClickButtonByName("confirm") or tryClickButtonByName("yes") or tryClickButtonByName("buy")
                task.wait(0.8)
                if not carToBuy.Parent then purchaseSuccess = true; break end
            end
             
            if not purchaseSuccess and carToBuy.Parent then
                updateStatus("Compra fallida.")
                task.wait(FAIL_DELAY)
            else
                updateStatus("¡Compra exitosa!")
                local hoodPart = carToBuy:FindFirstChild("Misc") and carToBuy.Misc:FindFirstChild("Hood") and carToBuy.Misc.Hood:FindFirstChild("Detector") and carToBuy.Misc.Hood.Detector:FindFirstChild("ClickDetector")
                if hoodPart then fireclickdetector(hoodPart); task.wait(3) 
                else
                     local anyCD = carToBuy:FindFirstChild("Hood", true)
                     if anyCD then local cd = anyCD:FindFirstChildWhichIsA("ClickDetector", true); if cd then fireclickdetector(cd); task.wait(3) end end
                end
                
                if currentMode == "BUY" then startAutoRepair() end
            end
        end
        
        isAutoBuyCarBuying = false
        if currentMode == "BUY" and #autoBuyCarQueue == 0 and not isRepairRunning then task.spawn(scanExistingCars) end
    end
end)

if displayMessageEvent then
    displayMessageEvent.OnClientEvent:Connect(function(...)
        if currentMode ~= "BUY" then return end 
        local args = {...}; local text = args[2]
        if not text or type(text) ~= "string" then return end
         
        local percentStr = text:match("(%d+)%%")
        local model = text:match("([%w%s]+) has appeared") or text:match("([%w%s]+)%s*%d+%%")

        if percentStr and model then
            local percent = tonumber(percentStr)
            if percent <= VIP_THRESHOLD then
                task.wait(0.5)
                local children = VEHICLES_FOLDER:GetChildren()
                local lastCar = children[#children]
                if lastCar and lastCar:IsA("Model") and not isCarInQueue(lastCar) then
                    Rayfield:Notify({Title = "Evento VIP", Content = "Nuevo auto: " .. percent .. "%", Duration = 4})
                    table.insert(autoBuyCarQueue, {car = lastCar, percent = percent})  
                    updateStatus("Cola VIP: " .. #autoBuyCarQueue)
                end
            end
        end
    end)
end

Rayfield:Notify({Title = "V5.5 Cargada", Content = "Pintura remota lista.", Duration = 5})
