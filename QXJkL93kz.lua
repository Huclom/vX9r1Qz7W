print("--- CARGANDO MAQUINA DE ESTADO V4.20 (HOOD ORDER & TRANS VALUE FIX) ---")

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager") 

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local playerData = player:WaitForChild("PlayerData")

local RS_Events = ReplicatedStorage:WaitForChild("Events", 10)
local CONFIRM_REMOTE = RS_Events and RS_Events:FindFirstChild("HUD", true) and RS_Events:FindFirstChild("HUD", true):FindFirstChild("Confirmation")
local displayMessageEvent = RS_Events and RS_Events:FindFirstChild("DisplayMessage")
local setPaintEvent = RS_Events and RS_Events:FindFirstChild("Vehicles", true) and RS_Events:FindFirstChild("Vehicles", true):FindFirstChild("SetPaint")

local NOTIFY_REMOTE = RS_Events:WaitForChild("HUD"):WaitForChild("Notifiy")
local remoteLoad = RS_Events:WaitForChild("Vehicles"):WaitForChild("RemoteLoad")

local currentMode = "OFF"
local isRepairRunning = false
local repairThread = nil
local isAutoBuyCarBuying = false
local autoBuyCarQueue = {} 

local MAX_PERCENT = 10
local VENDEDOR_CFRAME = CFrame.new(-1903.80859, 4.57728004, -779.534912, 0.00912900362, -6.48468301e-08, 0.999958336, 1.85525124e-08, 1, 6.46801581e-08, -0.999958336, 1.79612734e-08, 0.00912900362)
local AUTOS_PARA_VENDER = {
    "Merquis C203", "Missah 750x", "Matsu Lanca", "Lokswag Golo GT", "BNV K5 e39",
    "Four Traffic", "Lokswag Golo MK5", "Toyoda Hellox", "Holde Inteiro",
    "Leskus not200", "BNV K3", "Missah Silva", "Siath Lion", "Fia-Te Ponto",
    "Peujo 200e6", "Ontel Costa", "Lokswag Golo", "Renas Kapturado", "Sacode Oitava",
    "Lokswag Passar", "Lokswag Golo MK4", "Auidy V4", "Holde Ciwiq", "BNV K3 e92", "Chule Camarao"
}
local VENDER_PROMPT = Workspace:WaitForChild("Map"):WaitForChild("SellCar"):WaitForChild("Prompt"):WaitForChild("ProximityPrompt")

-- ==============================================================================
-- UTILIDADES UI
-- ==============================================================================
local function findButtonByExactText(textToFind)
    local topbar = playerGui:FindFirstChild("TopbarStandardClipped")
    local container = topbar and topbar:FindFirstChild("ClippedContainer")
    if not container then return nil end
    for _, descendant in ipairs(container:GetDescendants()) do
        if descendant:IsA("TextLabel") and descendant.Text == textToFind then
            return descendant.Parent 
        end
    end
    return nil
end

local function clickGUIButton(uiObject)
    if not uiObject then return false end
    local absPos = uiObject.AbsolutePosition
    local absSize = uiObject.AbsoluteSize
    local center = absPos + (absSize / 2)
    VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
    task.wait(0.1)
    VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
    return true
end

-- ==============================================================================
-- GUI SETUP
-- ==============================================================================
local startAutoRepair
local buyCar
local startAutoSellLoop
local processBuyQueue

local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "MasterControlGUI_V420"; ScreenGui.Parent = playerGui; ScreenGui.ResetOnSpawn = false
local MainFrame = Instance.new("Frame"); MainFrame.Name = "MainFrame"; MainFrame.Size = UDim2.new(0, 250, 0, 280); MainFrame.Position = UDim2.new(0.5, -125, 0, 100);
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30); MainFrame.Draggable = true; MainFrame.Active = true; MainFrame.Parent = ScreenGui
local UICorner = Instance.new("UICorner"); UICorner.CornerRadius = UDim.new(0, 8); UICorner.Parent = MainFrame
local TitleLabel = Instance.new("TextLabel"); TitleLabel.Name = "Title"; TitleLabel.Size = UDim2.new(1, 0, 0, 30); TitleLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 45);
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255); TitleLabel.Text = "V4.20 (Hood Order & Value Fix)"; TitleLabel.Font = Enum.Font.SourceSansBold; TitleLabel.TextSize = 16; TitleLabel.Parent = MainFrame

local MasterToggleButton = Instance.new("TextButton"); MasterToggleButton.Name = "MasterToggleButton"; MasterToggleButton.Size = UDim2.new(0.9, 0, 0, 40); MasterToggleButton.Position = UDim2.new(0.05, 0, 0, 40);
MasterToggleButton.BackgroundColor3 = Color3.fromRGB(170, 0, 0); MasterToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255); MasterToggleButton.Text = "Sistema Total (OFF)"; MasterToggleButton.Font = Enum.Font.SourceSansBold; MasterToggleButton.TextSize = 18; MasterToggleButton.Parent = MainFrame

local StatusMode = Instance.new("TextLabel"); StatusMode.Text = "MODO: OFF"; StatusMode.Size = UDim2.new(0.9, 0, 0, 20); StatusMode.Position = UDim2.new(0.05, 0, 0, 90); StatusMode.BackgroundTransparency = 1; StatusMode.TextColor3 = Color3.fromRGB(255, 255, 100); StatusMode.TextXAlignment = Enum.TextXAlignment.Left; StatusMode.Parent = MainFrame
local AutoBuyCarInfoLabel = Instance.new("TextLabel"); AutoBuyCarInfoLabel.Text = "Esperando..."; AutoBuyCarInfoLabel.Size = UDim2.new(0.9, 0, 0, 40); AutoBuyCarInfoLabel.Position = UDim2.new(0.05, 0, 0, 115); AutoBuyCarInfoLabel.BackgroundTransparency = 1; AutoBuyCarInfoLabel.TextColor3 = Color3.fromRGB(150, 255, 255); AutoBuyCarInfoLabel.TextWrapped = true; AutoBuyCarInfoLabel.TextXAlignment = Enum.TextXAlignment.Left; AutoBuyCarInfoLabel.Parent = MainFrame
local AutoBuyCarStatusLabel = Instance.new("TextLabel"); AutoBuyCarStatusLabel.Text = "COMPRA: Inactiva"; AutoBuyCarStatusLabel.Size = UDim2.new(0.9, 0, 0, 20); AutoBuyCarStatusLabel.Position = UDim2.new(0.05, 0, 0, 160); AutoBuyCarStatusLabel.BackgroundTransparency = 1; AutoBuyCarStatusLabel.TextColor3 = Color3.fromRGB(255, 150, 150); AutoBuyCarStatusLabel.TextXAlignment = Enum.TextXAlignment.Left; AutoBuyCarStatusLabel.Parent = MainFrame
local RepairStatusLabel = Instance.new("TextLabel"); RepairStatusLabel.Text = "REPAIR: Inactivo"; RepairStatusLabel.Size = UDim2.new(0.9, 0, 0, 20); RepairStatusLabel.Position = UDim2.new(0.05, 0, 0, 185); RepairStatusLabel.BackgroundTransparency = 1; RepairStatusLabel.TextColor3 = Color3.fromRGB(255, 150, 150); RepairStatusLabel.TextXAlignment = Enum.TextXAlignment.Left; RepairStatusLabel.Parent = MainFrame
local SellStatusLabel = Instance.new("TextLabel"); SellStatusLabel.Text = "VENTA: Inactiva"; SellStatusLabel.Size = UDim2.new(0.9, 0, 0, 20); SellStatusLabel.Position = UDim2.new(0.05, 0, 0, 210); SellStatusLabel.BackgroundTransparency = 1; SellStatusLabel.TextColor3 = Color3.fromRGB(255, 150, 150); SellStatusLabel.TextXAlignment = Enum.TextXAlignment.Left; SellStatusLabel.Parent = MainFrame

-- Botón Manual de Basura
local TrashManualButton = Instance.new("TextButton"); TrashManualButton.Text = "🗑️"; TrashManualButton.Size = UDim2.new(0.2, 0, 0, 25); TrashManualButton.Position = UDim2.new(0.75, 0, 0, 245); TrashManualButton.BackgroundColor3 = Color3.fromRGB(100, 30, 30); TrashManualButton.TextColor3 = Color3.fromRGB(255, 255, 255); TrashManualButton.Parent = MainFrame
local TrashLabel = Instance.new("TextLabel"); TrashLabel.Text = "Borrar Suelo:"; TrashLabel.Size = UDim2.new(0.6, 0, 0, 25); TrashLabel.Position = UDim2.new(0.1, 0, 0, 245); TrashLabel.BackgroundTransparency = 1; TrashLabel.TextColor3 = Color3.fromRGB(200, 200, 200); TrashLabel.TextXAlignment = Enum.TextXAlignment.Right; TrashLabel.Parent = MainFrame
TrashManualButton.MouseButton1Click:Connect(function() local b = findButtonByExactText("Delete dropped parts"); if b then clickGUIButton(b) end end)

local function updateGUI(mode)
    StatusMode.Text = "MODO: "..mode
    if mode == "BUY_REPAIR" then MasterToggleButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0); MasterToggleButton.Text = "Sistema Total (ON)"
    elseif mode == "SELL" then MasterToggleButton.BackgroundColor3 = Color3.fromRGB(255, 150, 0); MasterToggleButton.Text = "Sistema Total (VENDIENDO)"
    elseif mode == "OFF" then MasterToggleButton.BackgroundColor3 = Color3.fromRGB(170, 0, 0); MasterToggleButton.Text = "Sistema Total (OFF)" end
end
updateGUI(currentMode)

local function masterOnClientInvoke(text) if currentMode == "BUY_REPAIR" or currentMode == "SELL" then return true end; if _G.Confirmation then return _G.Confirmation(text) end; return false end
if CONFIRM_REMOTE then CONFIRM_REMOTE.OnClientInvoke = masterOnClientInvoke end

if NOTIFY_REMOTE then
    NOTIFY_REMOTE.OnClientEvent:Connect(function(text, color)
        if currentMode == "BUY_REPAIR" and text == "Garage limit reached" then
            currentMode = "SELL"; updateGUI(currentMode); if repairThread then task.cancel(repairThread); isRepairRunning = false end; task.spawn(startAutoSellLoop)
        end
    end)
end

startAutoSellLoop = function()
    local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local garageFolder = playerData:WaitForChild("Garage")
    rootPart.CFrame = VENDEDOR_CFRAME
    task.wait(1) 
    for _, carData in ipairs(garageFolder:GetChildren()) do
        if currentMode ~= "SELL" then break end 
        local modelName = carData:FindFirstChild("Model") and carData.Model.Value
        if not modelName then continue end 
        if table.find(AUTOS_PARA_VENDER, modelName) then
            SellStatusLabel.Text = "VENTA: "..modelName
            local carIDToSell = carData.Name
            local targetCFrame = rootPart.CFrame * CFrame.new(0, 3, 12)
            pcall(function() remoteLoad:InvokeServer(carData, targetCFrame) end)
            local carInWorld = Workspace.Vehicles:WaitForChild(carIDToSell, 5)
            if carInWorld then
                carInWorld:PivotTo(targetCFrame); task.wait(0.5); pcall(fireproximityprompt, VENDER_PROMPT, 0); task.wait(2.5) 
            end
        end
    end
    currentMode = "BUY_REPAIR"; processBuyQueue()
end

processBuyQueue = function()
    if currentMode ~= "BUY_REPAIR" or isRepairRunning or isAutoBuyCarBuying then return end
    if #autoBuyCarQueue > 0 then isAutoBuyCarBuying = true; local nextCar = table.remove(autoBuyCarQueue, 1); task.spawn(buyCar, nextCar) end
end

buyCar = function(carModel)
    if not carModel then isAutoBuyCarBuying = false; return end
    local cd = carModel:FindFirstChild("ClickDetector")
    if not cd then isAutoBuyCarBuying = false; return end
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root then isAutoBuyCarBuying = false; return end

    print("COMPRA: Moviendo al auto...")
    root.CFrame = carModel:GetPivot() * CFrame.new(-8, 0, 0)
    task.wait(0.8)
    fireclickdetector(cd)
    task.wait(0.5) -- Esperar confirmación de compra
    
    -- >>> NUEVO ORDEN: ABRIR CAPO AQUÍ <<<
    print("COMPRA: Intentando abrir capó inmediatamente (distancia cercana)...")
    local hoodCD = carModel:FindFirstChild("Misc", true) and carModel:FindFirstChild("Misc", true):FindFirstChild("Hood", true) and carModel:FindFirstChild("Misc", true):FindFirstChild("Hood", true):FindFirstChild("Detector", true) and carModel:FindFirstChild("Misc", true):FindFirstChild("Hood", true):FindFirstChild("Detector", true):FindFirstChild("ClickDetector")
    
    if hoodCD then
        fireclickdetector(hoodCD)
        print("COMPRA: ¡Capó activado! Esperando animación...")
        task.wait(1.5) 
    else
        print("COMPRA: No se encontró capó (o no tiene). Continuando...")
    end

    if currentMode == "BUY_REPAIR" then
        isRepairRunning = true
        repairThread = task.spawn(startAutoRepair)
    else
        isRepairRunning = false; isAutoBuyCarBuying = false 
    end
end

-- ==============================================================================
-- LOGICA DE REPARACION (V4.20)
-- ==============================================================================
startAutoRepair = function() 
    if currentMode ~= "BUY_REPAIR" and not isRepairRunning then return end
    task.wait(1) -- Pequeña pausa tras abrir capó
    RepairStatusLabel.Text = "REPAIR: V4.20..."

    local character = player.Character
    local rootPart = character:WaitForChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then humanoid.Sit = false; humanoid.Jump = true end

    -- Mapa base (Ranura -> Maquina)
    local machineMap = {
        ["Battery"] = "BatteryCharger",
        ["AirIntake"] = "PartsWasher",
        ["Radiator"] = "PartsWasher",
        ["CylinderHead"] = "GrindingMachine",
        ["EngineBlock"] = "GrindingMachine",
        ["ExhaustManifold"] = "GrindingMachine",
        ["Suspension"] = "GrindingMachine",
        ["Alternator"] = "GrindingMachine",
        ["Transmission"] = "GrindingMachine" -- Se mapeará dinámicamente
    }

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
    
    local function findClosestCar()
        local vehiclesFolder = Workspace:WaitForChild("Vehicles")
        local closest = nil; local minDst = math.huge
        for _, car in ipairs(vehiclesFolder:GetChildren()) do
            if car:IsA("Model") and car:GetAttribute("Owner") == player.Name then
                local dist = (rootPart.Position - car:GetPivot().Position).Magnitude
                if dist < minDst then minDst = dist; closest = car end
            end
        end; return closest
    end 

    local pitStop = getPitStop()
    local carModel = findClosestCar()
    
    if not pitStop or not carModel then isRepairRunning = false; isAutoBuyCarBuying = false; processBuyQueue(); return end
    
    -- Ahora hacemos el TP al taller (El capó YA debe estar abierto)
    print("REPAIR: Moviendo al taller...")
    rootPart.CFrame = pitStop:GetPivot() * CFrame.new(0, 3, 5)
    task.wait(1)

    local carPartsEvent = carModel:FindFirstChild("PartsEvent")
    local engineBay = carModel:FindFirstChild("Body", true) and carModel:FindFirstChild("Body", true):FindFirstChild("EngineBay", true)
    local carData = carModel:FindFirstChild("Values", true) and carModel:FindFirstChild("Values", true):FindFirstChild("Engine", true)

    if not carPartsEvent or not engineBay then isRepairRunning = false; isAutoBuyCarBuying = false; processBuyQueue(); return end

    local allPartNames = {}
    local partsToRepair_Names = {} 
    local partsToBuy_Data = {} 
    
    -- Mapa: Nombre en Motor -> Nombre en Suelo
    local droppedPartNameMap = {} 
    
    local engineType = carData.EngineBlock.Value

    for _, partModel in ipairs(engineBay:GetChildren()) do
        if partModel:IsA("Model") and partModel:FindFirstChild("Main") then
            local fullPartName = partModel.Name -- Ej: "V8Transmission"
            
            -- 1. Obtener nombre base limpio
            local basePartName = fullPartName:gsub(engineType, ""):gsub("^-", ""):gsub("^_", ""):gsub("-$", ""):gsub("_$", "")
            
            -- 2. Detectar nombre REAL al caer (Leyendo StringValue "Value")
            local droppedName = basePartName -- Por defecto es igual
            local valueObj = partModel:FindFirstChild("Value")
            
            if valueObj and valueObj:IsA("StringValue") then
                -- Formato esperado: "Transmission|6-Speed Manual"
                local splitVal = string.split(valueObj.Value, "|")
                if #splitVal >= 2 then
                    droppedName = splitVal[2] -- "6-Speed Manual"
                    print("   [INFO] Pieza Compuesta: "..basePartName.." -> Cae como: "..droppedName)
                end
            end
            
            -- Guardamos el mapa: "V8Transmission" -> "6-Speed Manual"
            droppedPartNameMap[fullPartName] = droppedName

            table.insert(allPartNames, fullPartName) 
            
            if machineMap[basePartName] then
                table.insert(partsToRepair_Names, fullPartName)
            else
                -- Si no es reparable, compramos usando el nombre compuesto si existe
                local partString = "ENGINE|" .. engineType .. "|" .. droppedName
                table.insert(partsToBuy_Data, partString)
            end
        end
    end
    
    -- DESMONTAJE
    for _, partName in ipairs(allPartNames) do 
        if not isRepairRunning then break end
        pcall(function() carPartsEvent:FireServer("RemovePart", partName) end)
        task.wait(0.1) 
    end

    task.wait(1.5) 
    local bringBtn = findButtonByExactText("Bring dropped parts")
    if bringBtn then clickGUIButton(bringBtn); task.wait(2) end
    
    local moveablePartsFolder = Workspace:WaitForChild("MoveableParts")
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
            
            -- AQUI ESTA LA MAGIA V4.20:
            -- Buscamos en el suelo usando el nombre MAPEADO ("6-Speed Manual")
            local targetDroppedName = droppedPartNameMap[partSlotName] or partSlotName
            local partObject = moveablePartsFolder:FindFirstChild(targetDroppedName)
            
            if partObject then
                local wear = partObject:GetAttribute("Wear") or 0
                if wear > 0 then
                    -- Calculamos máquina basada en el nombre de la ranura (Ej: Transmission -> Grinder)
                    local basePartName = partSlotName:gsub(engineType, ""):gsub("^-", ""):gsub("^_", ""):gsub("-$", ""):gsub("_$", "")
                    
                    local machineName = machineMap[basePartName]
                    local pool = machinePools[machineName]
                    if pool and #pool > 0 then
                        local idx = machineIndexes[machineName]
                        local machine = pool[idx]
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
                local wear = data.Part:GetAttribute("Wear") or 0
                if wear == 0 then
                    table.remove(partsBeingRepaired, i)
                elseif (os.clock() - data.StartTime) > 20 then
                    data.StartTime = os.clock()
                    local detectorPad = data.Machine:FindFirstChild("Detector", true)
                    data.Part:PivotTo(detectorPad.CFrame * CFrame.new(0, 0.5, 0))
                    fireclickdetector(data.CD)
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

    -- REINSTALACION (Usando el mapa también)
    for _, partSlotName in ipairs(allPartNames) do
        if not isRepairRunning then break end 
        
        -- Nombre físico que buscamos en el suelo
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

    -- Capó ya estaba abierto, intentamos cerrarlo
    local hoodCD = carModel:FindFirstChild("Misc", true) and carModel:FindFirstChild("Misc", true):FindFirstChild("Hood", true) and carModel:FindFirstChild("Misc", true):FindFirstChild("Hood", true):FindFirstChild("Detector", true) and carModel:FindFirstChild("Misc", true):FindFirstChild("Hood", true):FindFirstChild("Detector", true):FindFirstChild("ClickDetector")
    if hoodCD then fireclickdetector(hoodCD); task.wait(1) end
    
    local carSeat = carModel:FindFirstChild("DriveSeat") or carModel:FindFirstChildOfClass("BasePart", true)
    if carSeat then rootPart.CFrame = carSeat.CFrame * CFrame.new(0, 3, 15); task.wait(1) end

    local paintPrompt = Workspace:WaitForChild("Map"):WaitForChild("pintamento"):WaitForChild("CarPaint"):FindFirstChild("Prompt", true):FindFirstChild("ProximityPrompt")
    if paintPrompt and setPaintEvent then
        local newColor = Color3.fromHSV(math.random(), 1, 1)
        pcall(fireproximityprompt, paintPrompt, 0)
        task.wait(0.5)
        pcall(function() setPaintEvent:FireServer(carModel, newColor) end)
        task.wait(2)
    end
    
    if isRepairRunning then
        isRepairRunning = false
        RepairStatusLabel.Text = "REPAIR: Listo"
        isAutoBuyCarBuying = false 
        processBuyQueue()
    end
end

displayMessageEvent.OnClientEvent:Connect(function(...)
    if currentMode ~= "BUY_REPAIR" then return end
    local args = {...}
    local text = args[2]
    if not text or type(text) ~= "string" then return end
    local percent = text:match("(%d+)%%")
    local model = text:match("([%w%s]+) has appeared") or text:match("([%w%s]+)%s*%d+%%")
    if percent and model and tonumber(percent) <= MAX_PERCENT then
        local lastCar = Workspace.Vehicles:GetChildren()[#Workspace.Vehicles:GetChildren()]
        if lastCar and lastCar:IsA("Model") and not table.find(autoBuyCarQueue, lastCar) then
            AutoBuyCarInfoLabel.Text = "Junk: " .. model .. " (" .. percent .. "%)"
            table.insert(autoBuyCarQueue, lastCar) 
            processBuyQueue()
        end
    end
end)

MasterToggleButton.MouseButton1Click:Connect(function()
    if currentMode == "OFF" then currentMode = "BUY_REPAIR"; processBuyQueue()
    else currentMode = "OFF"; if repairThread then task.cancel(repairThread) end; isRepairRunning = false; isAutoBuyCarBuying = false end
    updateGUI(currentMode)
end)

print("--- V4.20 (FINAL LOGIC) CARGADO ---")
