-- =================================================================
-- --- SCRIPT MAESTRO (V4.48): "FUERZA BRUTA" ---
-- --- FIX: Clicks físicos + Auto-Confirmar GUI (Si falla el hook) ---
-- =================================================================
print("--- CARGANDO MAQUINA DE ESTADO V4.48 (PHYSICAL CLICK FIX) ---")

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager") 
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local playerData = player:WaitForChild("PlayerData")
local camera = Workspace.CurrentCamera

local RS_Events = ReplicatedStorage:WaitForChild("Events", 10)
local CONFIRM_REMOTE = RS_Events and RS_Events:FindFirstChild("HUD", true) and RS_Events:FindFirstChild("HUD", true):FindFirstChild("Confirmation")
local displayMessageEvent = RS_Events:WaitForChild("DisplayMessage")
local NOTIFY_REMOTE = RS_Events:WaitForChild("HUD"):WaitForChild("Notifiy")
local remoteLoad = RS_Events:WaitForChild("Vehicles"):WaitForChild("RemoteLoad")
local setPaintEvent = RS_Events and RS_Events:FindFirstChild("Vehicles", true) and RS_Events:FindFirstChild("Vehicles", true):FindFirstChild("SetPaint")
local VEHICLES_FOLDER = Workspace:WaitForChild("Vehicles", 10)

-- --- CONFIGURACIÓN ---
local currentMode = "OFF"
local isAutoBuyCarBuying = false 
local autoBuyCarQueue = {} 
local isRepairRunning = false 
local FAIL_DELAY = 5 
local VENDEDOR_CFRAME = CFrame.new(-1903.80859, 4.57728004, -779.534912, 0.00912900362, -6.48468301e-08, 0.999958336, 1.85525124e-08, 1, 6.46801581e-08, -0.999958336, 1.79612734e-08, 0.00912900362)

local AUTOS_PARA_VENDER = {
    "Merquis C203", "Missah 750x", "Matsu Lanca", "Lokswag Golo GT", "BNV K5 e39",
    "Four Traffic", "Lokswag Golo MK5", "Toyoda Hellox", "Holde Inteiro",
    "Leskus not200", "BNV K3", "Missah Silva", "Siath Lion", "Fia-Te Ponto",
    "Peujo 200e6", "Ontel Costa", "Lokswag Golo", "Renas Kapturado", "Sacode Oitava",
    "Lokswag Passar", "Lokswag Golo MK4", "Auidy V4", "Holde Ciwiq", "BNV K3 e92", "Chule Camarao", "Auidy V5"
}

-- --- UTILIDADES UI ---
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

-- >>> V4.48: NUEVA FUNCIÓN CLICK FÍSICO <<<
local function forcePhysicalClick(targetPart)
    if not targetPart then return end
    
    -- 1. Mirar al objeto
    camera.CFrame = CFrame.new(camera.CFrame.Position, targetPart.Position)
    task.wait(0.1)
    
    -- 2. Click al centro de la pantalla (donde estamos mirando)
    local viewportSize = camera.ViewportSize
    local centerX = viewportSize.X / 2
    local centerY = viewportSize.Y / 2
    
    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
    task.wait(0.1)
    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
end

-- >>> V4.48: NUEVA FUNCIÓN AUTO-CONFIRMAR GUI <<<
local function checkAndClickConfirmGUI()
    -- Buscar botones verdes o con texto "Yes" que aparezcan en pantalla
    for _, gui in ipairs(playerGui:GetDescendants()) do
        if gui:IsA("TextButton") or (gui:IsA("TextLabel") and gui.Parent:IsA("GuiButton")) then
            local text = gui.Text:lower()
            if text == "yes" or text == "confirm" or text == "buy" then
                if gui:IsDescendantOf(playerGui) and gui.Visible then
                    local btn = gui:IsA("GuiButton") and gui or gui.Parent
                    print("GUI: Detectado botón de confirmación. Click!")
                    clickGUIButton(btn)
                    return true
                end
            end
        end
    end
    return false
end

-- --- DECLARACIÓN ADELANTADA ---
local startAutoSellLoop
local scanExistingCars
local startAutoRepair
local buyCar

-- --- INTERFAZ GRÁFICA (GUI) ---
local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "MasterControlGUI_V448"; ScreenGui.Parent = playerGui; ScreenGui.ResetOnSpawn = false
local MainFrame = Instance.new("Frame"); MainFrame.Name = "MainFrame"; MainFrame.Size = UDim2.new(0, 250, 0, 280); MainFrame.Position = UDim2.new(0.5, -125, 0, 100);
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30); MainFrame.Draggable = true; MainFrame.Active = true; MainFrame.Parent = ScreenGui
local UICorner = Instance.new("UICorner"); UICorner.CornerRadius = UDim.new(0, 8); UICorner.Parent = MainFrame
local TitleLabel = Instance.new("TextLabel"); TitleLabel.Name = "Title"; TitleLabel.Size = UDim2.new(1, 0, 0, 30); TitleLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 45);
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255); TitleLabel.Text = "V4.48 (Fuerza Bruta)"; TitleLabel.Font = Enum.Font.SourceSansBold; TitleLabel.TextSize = 16; TitleLabel.Parent = MainFrame

local MasterToggleButton = Instance.new("TextButton"); MasterToggleButton.Size = UDim2.new(0.9, 0, 0, 40); MasterToggleButton.Position = UDim2.new(0.05, 0, 0, 40);
MasterToggleButton.BackgroundColor3 = Color3.fromRGB(170, 0, 0); MasterToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255); MasterToggleButton.Text = "Sistema Total (OFF)"; MasterToggleButton.Font = Enum.Font.SourceSansBold; MasterToggleButton.TextSize = 18; MasterToggleButton.Parent = MainFrame

local StatusMode = Instance.new("TextLabel"); StatusMode.Text = "MODO: OFF"; StatusMode.Size = UDim2.new(0.9, 0, 0, 20); StatusMode.Position = UDim2.new(0.05, 0, 0, 90); StatusMode.BackgroundTransparency = 1; StatusMode.TextColor3 = Color3.fromRGB(255, 255, 100); StatusMode.TextXAlignment = Enum.TextXAlignment.Left; StatusMode.Parent = MainFrame
local AutoBuyCarInfoLabel = Instance.new("TextLabel"); AutoBuyCarInfoLabel.Text = "Cola: 0"; AutoBuyCarInfoLabel.Size = UDim2.new(0.9, 0, 0, 40); AutoBuyCarInfoLabel.Position = UDim2.new(0.05, 0, 0, 115); AutoBuyCarInfoLabel.BackgroundTransparency = 1; AutoBuyCarInfoLabel.TextColor3 = Color3.fromRGB(150, 255, 255); AutoBuyCarInfoLabel.TextWrapped = true; AutoBuyCarInfoLabel.TextXAlignment = Enum.TextXAlignment.Left; AutoBuyCarInfoLabel.Parent = MainFrame
local AutoBuyCarStatusLabel = Instance.new("TextLabel"); AutoBuyCarStatusLabel.Text = "COMPRA: Inactiva"; AutoBuyCarStatusLabel.Size = UDim2.new(0.9, 0, 0, 20); AutoBuyCarStatusLabel.Position = UDim2.new(0.05, 0, 0, 160); AutoBuyCarStatusLabel.BackgroundTransparency = 1; AutoBuyCarStatusLabel.TextColor3 = Color3.fromRGB(255, 150, 150); AutoBuyCarStatusLabel.TextXAlignment = Enum.TextXAlignment.Left; AutoBuyCarStatusLabel.Parent = MainFrame
local RepairStatusLabel = Instance.new("TextLabel"); RepairStatusLabel.Text = "REPAIR: Inactivo"; RepairStatusLabel.Size = UDim2.new(0.9, 0, 0, 20); RepairStatusLabel.Position = UDim2.new(0.05, 0, 0, 185); RepairStatusLabel.BackgroundTransparency = 1; RepairStatusLabel.TextColor3 = Color3.fromRGB(255, 150, 150); RepairStatusLabel.TextXAlignment = Enum.TextXAlignment.Left; RepairStatusLabel.Parent = MainFrame
local SellStatusLabel = Instance.new("TextLabel"); SellStatusLabel.Text = "VENTA: Inactiva"; SellStatusLabel.Size = UDim2.new(0.9, 0, 0, 20); SellStatusLabel.Position = UDim2.new(0.05, 0, 0, 210); SellStatusLabel.BackgroundTransparency = 1; SellStatusLabel.TextColor3 = Color3.fromRGB(255, 150, 150); SellStatusLabel.TextXAlignment = Enum.TextXAlignment.Left; SellStatusLabel.Parent = MainFrame

local TrashManualButton = Instance.new("TextButton"); TrashManualButton.Text = "🗑️"; TrashManualButton.Size = UDim2.new(0.2, 0, 0, 25); TrashManualButton.Position = UDim2.new(0.75, 0, 0, 245); TrashManualButton.BackgroundColor3 = Color3.fromRGB(100, 30, 30); TrashManualButton.TextColor3 = Color3.fromRGB(255, 255, 255); TrashManualButton.Parent = MainFrame
local TrashLabel = Instance.new("TextLabel"); TrashLabel.Text = "Borrar Suelo:"; TrashLabel.Size = UDim2.new(0.6, 0, 0, 25); TrashLabel.Position = UDim2.new(0.1, 0, 0, 245); TrashLabel.BackgroundTransparency = 1; TrashLabel.TextColor3 = Color3.fromRGB(200, 200, 200); TrashLabel.TextXAlignment = Enum.TextXAlignment.Right; TrashLabel.Parent = MainFrame
TrashManualButton.MouseButton1Click:Connect(function() local b = findButtonByExactText("Delete dropped parts"); if b then clickGUIButton(b) end end)

local function updateGUI(mode)
    StatusMode.Text = "MODO: "..mode
    if mode == "BUY" then
        MasterToggleButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0); MasterToggleButton.Text = "Sistema Total (ON)"
    elseif mode == "SELL" then
        MasterToggleButton.BackgroundColor3 = Color3.fromRGB(255, 150, 0); MasterToggleButton.Text = "Sistema Total (VENDIENDO)"
    elseif mode == "OFF" then
        MasterToggleButton.BackgroundColor3 = Color3.fromRGB(170, 0, 0); MasterToggleButton.Text = "Sistema Total (OFF)"
    end
end
updateGUI(currentMode)

-- --- MASTER HOOK (CONFIRMACIÓN REMOTA) ---
local function masterOnClientInvoke(text)
    print("HOOK: Se solicitó confirmación con texto: " .. tostring(text))
    if currentMode == "BUY" or currentMode == "SELL" then return true end
    if _G.Confirmation then return _G.Confirmation(text) end
    return false
end

if CONFIRM_REMOTE then
    CONFIRM_REMOTE.OnClientInvoke = masterOnClientInvoke
else
    print("WARN: No se encontró Remote de Confirmación. Se usará escáner GUI.")
end

if NOTIFY_REMOTE then
    NOTIFY_REMOTE.OnClientEvent:Connect(function(text)
        if currentMode == "BUY" and text == "Garage limit reached" then 
            currentMode = "SELL"; updateGUI(currentMode)
            if isRepairRunning then isRepairRunning = false end 
            task.spawn(startAutoSellLoop)
        end
    end)
end

local function getSellPrompt()
    local map = Workspace:FindFirstChild("Map")
    local sellCar = map and map:FindFirstChild("SellCar")
    return sellCar and sellCar:FindFirstChildWhichIsA("ProximityPrompt", true)
end

-- =================================================================
-- LOGICA DE VENTA (V4.47)
-- =================================================================
startAutoSellLoop = function()
    local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local garageFolder = playerData:WaitForChild("Garage")
    
    print("VENTA: Iniciando viaje al vendedor...")
    SellStatusLabel.Text = "VENTA: Viajando..."
    
    local arrived = false
    for i = 1, 10 do 
        rootPart.CFrame = VENDEDOR_CFRAME
        task.wait(0.5)
        if (rootPart.Position - VENDEDOR_CFRAME.Position).Magnitude < 10 then arrived = true; break end
    end
    
    if not arrived then
        print("VENTA: Fallo al teletransportar. Reintentando...")
        startAutoSellLoop()
        return
    end
    
    print("VENTA: Llegada confirmada. Esperando carga...")
    task.wait(2)
    
    local promptVenta = getSellPrompt()
    
    for _, carData in ipairs(garageFolder:GetChildren()) do
        if currentMode ~= "SELL" then break end 
        local modelName = carData:FindFirstChild("Model") and carData.Model.Value
        if not modelName then continue end 

        if table.find(AUTOS_PARA_VENDER, modelName) then
            SellStatusLabel.Text = "VENTA: "..modelName
            local carIDToSell = carData.Name
            local targetCFrame = rootPart.CFrame * CFrame.new(0, 3, 12)
            
            if (rootPart.Position - VENDEDOR_CFRAME.Position).Magnitude > 15 then
                rootPart.CFrame = VENDEDOR_CFRAME
                task.wait(0.5)
            end
            
            pcall(function() remoteLoad:InvokeServer(carData, targetCFrame) end)
            local carInWorld = Workspace.Vehicles:WaitForChild(carIDToSell, 5)
            
            if carInWorld then
                carInWorld:PivotTo(targetCFrame)
                if setPaintEvent then
                   pcall(function() setPaintEvent:FireServer(carInWorld, Color3.fromHSV(math.random(), 1, 1)) end)
                end
                task.wait(0.5)
                if promptVenta then pcall(fireproximityprompt, promptVenta, 0) end
                task.wait(2.5)
            end
        end
    end
    
    currentMode = "BUY"
    updateGUI(currentMode)
    task.spawn(scanExistingCars)
end

-- =================================================================
-- LOGICA DE REPARACIÓN (V4.46)
-- =================================================================
startAutoRepair = function() 
    if currentMode ~= "BUY" then return end
    
    local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    local targetCar = nil
    print("REPAIR: Buscando auto propio cercano...")
    
    for i = 1, 10 do 
        local closest = nil
        local minDst = 20
        for _, car in ipairs(Workspace:WaitForChild("Vehicles"):GetChildren()) do
            if car:IsA("Model") and car:GetAttribute("Owner") == player.Name then
                local pivot = car:GetPivot().Position
                local dist = (rootPart.Position - pivot).Magnitude
                if dist < minDst then minDst = dist; closest = car end
            end
        end
        if closest then targetCar = closest; break end
        task.wait(0.5)
    end
    
    if not targetCar then
        print("REPAIR: No se encontró auto propio. Abortando.")
        isRepairRunning = false
        return
    end

    isRepairRunning = true
    task.wait(1)
    RepairStatusLabel.Text = "REPAIR: Iniciando..."

    local carModel = targetCar 
    local character = player.Character
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then humanoid.Sit = false; humanoid.Jump = true end

    local machineMap = { ["Battery"]="BatteryCharger", ["AirIntake"]="PartsWasher", ["Radiator"]="PartsWasher", ["CylinderHead"]="GrindingMachine", ["EngineBlock"]="GrindingMachine", ["ExhaustManifold"]="GrindingMachine", ["Suspension"]="GrindingMachine", ["Alternator"]="GrindingMachine", ["Transmission"]="GrindingMachine" }

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
    local existingParts = moveablePartsFolder:GetChildren()
    
    if #existingParts > 0 then
        local bringBtn = findButtonByExactText("Bring dropped parts")
        if bringBtn then clickGUIButton(bringBtn); task.wait(1.5) end
        local deleteBtn = findButtonByExactText("Delete dropped parts")
        if deleteBtn then
            clickGUIButton(deleteBtn)
            RepairStatusLabel.Text = "REPAIR: Borrando..."
            for i = 1, 8 do if #moveablePartsFolder:GetChildren() == 0 then break end; task.wait(1) end
        end
    end
    
    RepairStatusLabel.Text = "REPAIR: Trabajando..."

    local carPartsEvent = carModel:FindFirstChild("PartsEvent")
    local engineBay = carModel:FindFirstChild("Body", true) and carModel:FindFirstChild("Body", true):FindFirstChild("EngineBay", true)
    local carValuesFolder = carModel:FindFirstChild("Values", true) and carModel:FindFirstChild("Values", true):FindFirstChild("Engine", true)
    
    if not carPartsEvent or not engineBay or not carValuesFolder then isRepairRunning = false; return end

    local allPartNames = {}
    local partsToRepair_Names = {} 
    local partsToBuy_Data = {} 
    local droppedPartNameMap = {} 
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
    local bringBtn = findButtonByExactText("Bring dropped parts")
    if bringBtn then clickGUIButton(bringBtn); task.wait(2) end
    
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

    local hoodCD = carModel:FindFirstChild("Misc", true) and carModel:FindFirstChild("Misc", true):FindFirstChild("Hood", true) and carModel:FindFirstChild("Misc", true):FindFirstChild("Hood", true):FindFirstChild("Detector", true) and carModel:FindFirstChild("Misc", true):FindFirstChild("Hood", true):FindFirstChild("Detector", true):FindFirstChild("ClickDetector")
    if hoodCD then fireclickdetector(hoodCD); task.wait(1) end
    
    local carSeat = carModel:FindFirstChild("DriveSeat") or carModel:FindFirstChildOfClass("BasePart", true)
    if carSeat then rootPart.CFrame = carSeat.CFrame * CFrame.new(0, 3, 15); task.wait(1) end

    local paintPrompt = Workspace:WaitForChild("Map"):WaitForChild("pintamento"):WaitForChild("CarPaint"):FindFirstChild("Prompt", true):FindFirstChild("ProximityPrompt")
    if paintPrompt and setPaintEvent then
        pcall(fireproximityprompt, paintPrompt, 0)
        task.wait(0.5)
        pcall(function() setPaintEvent:FireServer(carModel, Color3.fromHSV(math.random(), 1, 1)) end)
        task.wait(2)
    end
    
    isRepairRunning = false
    RepairStatusLabel.Text = "REPAIR: Terminado"
end

-- --- 9. LOGICA COMPRA ---
local function isCarInQueue(carModel)
    for _, item in ipairs(autoBuyCarQueue) do
        if item.car == carModel then return true end
    end
    return false
end

scanExistingCars = function()
    if currentMode ~= "BUY" then return end
    print("--- Escaneando autos pre-existentes... ---")
    for _, carModel in ipairs(VEHICLES_FOLDER:GetChildren()) do
        if carModel:IsA("Model") and not isCarInQueue(carModel) then
            local cd = carModel:FindFirstChild("ClickDetector")
            if cd then 
                local percent = 100 
                local wearValue = carModel:GetAttribute("Wear")
                if wearValue then percent = math.floor(wearValue * 100) end
                table.insert(autoBuyCarQueue, {car = carModel, percent = percent})
            end
        end
    end
    AutoBuyCarInfoLabel.Text = "Cola: " .. #autoBuyCarQueue
    updateGUI(currentMode)
end

spawn(function()
    while true do
        task.wait(1)
        
        if isRepairRunning then
            AutoBuyCarStatusLabel.Text = "COMPRA: Esperando reparación..."
            continue
        end

        if currentMode ~= "BUY" or #autoBuyCarQueue == 0 or isAutoBuyCarBuying then continue end

        isAutoBuyCarBuying = true
        table.sort(autoBuyCarQueue, function(a, b) return a.percent < b.percent end)
        local item = table.remove(autoBuyCarQueue, 1)
        local carToBuy = item.car
        
        if not carToBuy or not carToBuy.Parent or not carToBuy:FindFirstChild("ClickDetector") then
            isAutoBuyCarBuying = false
            if #autoBuyCarQueue == 0 then task.spawn(scanExistingCars) end
            continue
        end

        repeat task.wait(0.1) until player.Character
        local root = player.Character:FindFirstChild("HumanoidRootPart")
        if not root then isAutoBuyCarBuying = false; continue end
        
        root.CFrame = carToBuy:GetPivot() * CFrame.new(-8, 0, 0)
        AutoBuyCarStatusLabel.Text = "COMPRA: Intentando..."
        task.wait(0.8)
        
        -- >>> V4.48 LOGICA DE REINTENTOS (DOBLE CLICK) <<<
        local purchaseSuccess = false
        for i = 1, 5 do
            if not carToBuy or not carToBuy.Parent then 
                purchaseSuccess = true
                break 
            end
            
            root.CFrame = carToBuy:GetPivot() * CFrame.new(-6, 0, 0)
            
            print("COMPRA: Click Fuerte #"..i)
            -- Metodo 1: Script
            fireclickdetector(carToBuy.ClickDetector)
            -- Metodo 2: Físico simulado
            forcePhysicalClick(carToBuy:FindFirstChild("Body") and carToBuy.Body:FindFirstChild("Part") or carToBuy.PrimaryPart)
            
            -- Metodo 3: Auto-Click Confirmación GUI
            checkAndClickConfirmGUI()
            
            task.wait(0.8)
            
            if not carToBuy.Parent then
                purchaseSuccess = true
                break
            end
        end
        -- >>> FIN REINTENTOS <<<
        
        if not purchaseSuccess and carToBuy.Parent then
            AutoBuyCarStatusLabel.Text = "COMPRA: Falló (Timeout)"
            task.wait(FAIL_DELAY)
            isAutoBuyCarBuying = false
            if #autoBuyCarQueue == 0 then task.spawn(scanExistingCars) end
            continue
        end

        AutoBuyCarStatusLabel.Text = "COMPRA: ¡Éxito!"
        
        -- ABRIR CAPO (V4.44 Logic)
        local hoodPart = carToBuy:FindFirstChild("Misc") and carToBuy.Misc:FindFirstChild("Hood") and carToBuy.Misc.Hood:FindFirstChild("Detector") and carToBuy.Misc.Hood.Detector:FindFirstChild("ClickDetector")
        if hoodPart then
            fireclickdetector(hoodPart)
            task.wait(3) 
        else
             local anyCD = carToBuy:FindFirstChild("Hood", true)
             if anyCD then
                 local cd = anyCD:FindFirstChildWhichIsA("ClickDetector", true)
                 if cd then fireclickdetector(cd); task.wait(3) end
            end
        end
        
        if currentMode == "BUY" then
            startAutoRepair()
        end
        
        isAutoBuyCarBuying = false
        if currentMode == "BUY" and #autoBuyCarQueue == 0 and not isRepairRunning then
            task.spawn(scanExistingCars)
        end
    end
end)

displayMessageEvent.OnClientEvent:Connect(function(...)
    if currentMode ~= "BUY" then return end 
    local args = {...}
    local text = args[2]
    if not text or type(text) ~= "string" then return end
    
    local percentStr = text:match("(%d+)%%")
    local model = text:match("([%w%s]+) has appeared") or text:match("([%w%s]+)%s*%d+%%")

    if percentStr and model then
        local percent = tonumber(percentStr)
        model = model:gsub("^%s*(.-)%s*$", "%1")
        task.wait(0.5)
        local children = VEHICLES_FOLDER:GetChildren()
        local lastCar = children[#children]
        
        if lastCar and lastCar:IsA("Model") and not isCarInQueue(lastCar) then
            print("EVENTO: Auto nuevo detectado. A cola.")
            table.insert(autoBuyCarQueue, {car = lastCar, percent = percent})  
            AutoBuyCarInfoLabel.Text = "Cola: " .. #autoBuyCarQueue
        end
    end
end)

MasterToggleButton.MouseButton1Click:Connect(function()
    if currentMode == "OFF" then
        currentMode = "BUY"
        task.spawn(scanExistingCars)
    else
        currentMode = "OFF"
        isAutoBuyCarBuying = false
        isRepairRunning = false
        autoBuyCarQueue = {} 
    end
    updateGUI(currentMode)
end)

print("--- V4.48 (PHYSICAL CLICK FIX) LISTA ---")
