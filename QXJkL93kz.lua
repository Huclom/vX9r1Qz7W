-- =================================================================
-- --- SCRIPT MAESTRO (V4.63): "VIP ONLY" ---
-- --- FIX: Solo busca y compra autos con porcentaje <= 10% ---
-- =================================================================
print("--- CARGANDO MAQUINA DE ESTADO V4.63 (VIP ONLY) ---")

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager") 
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 30)
local playerData = player:WaitForChild("PlayerData", 30)
local camera = Workspace.CurrentCamera

-- Carga Segura de Eventos
local RS_Events = ReplicatedStorage:WaitForChild("Events", 20)
if not RS_Events then warn("ERROR: No events found"); return end

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

-- --- CONFIGURACIÓN ---
local currentMode = "OFF"
local isAutoBuyCarBuying = false 
local autoBuyCarQueue = {} 
local isRepairRunning = false 
local FAIL_DELAY = 5 
local CLEAN_DELAY = 10 
local VIP_THRESHOLD = 10 -- UMBRAL DE CORTE: Solo autos de este % o menos
local VENDEDOR_CFRAME = CFrame.new(-1903.80859, 4.57728004, -779.534912, 0.00912900362, -6.48468301e-08, 0.999958336, 1.85525124e-08, 1, 6.46801581e-08, -0.999958336, 1.79612734e-08, 0.00912900362)

local AUTOS_PARA_VENDER = {
    "Merquis C203", "Missah 750x", "Matsu Lanca", "Lokswag Golo GT", "BNV K5 e39",
    "Four Traffic", "Lokswag Golo MK5", "Toyoda Hellox", "Holde Inteiro",
    "Leskus not200", "BNV K3", "Missah Silva", "Siath Lion", "Fia-Te Ponto",
    "Peujo 200e6", "Ontel Costa", "Lokswag Golo", "Renas Kapturado", "Sacode Oitava",
    "Lokswag Passar", "Lokswag Golo MK4", "Auidy V4", "Holde Ciwiq", "BNV K3 e92", "Chule Camarao", "Auidy V5", 
    "Sabes Muito", "Xitro J3", "Toyoda Yapp"
}

-- =================================================================
-- SISTEMA DE CLICK
-- =================================================================

local function highlightUI(guiObject)
    if not guiObject then return end
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 0, 0)
    stroke.Thickness = 4
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = guiObject
    Debris:AddItem(stroke, 2)
end

local function findButtonGlobal(textToFind)
    for _, descendant in ipairs(playerGui:GetDescendants()) do
        if descendant:IsA("TextLabel") then
            if descendant.Text:lower() == textToFind:lower() then
                local btn = descendant.Parent
                if btn and btn:IsA("GuiObject") then return btn end
            end
        end
    end
    return nil
end

local function clickGUIObject(guiObject)
    if not guiObject then return false end
    if not guiObject.Visible then return false end
     
    local absPos = guiObject.AbsolutePosition
    local absSize = guiObject.AbsoluteSize
    local centerX = absPos.X + (absSize.X / 2)
    local centerY = absPos.Y + (absSize.Y / 2)
     
    if centerX < 0 or centerY < 0 or centerX > camera.ViewportSize.X or centerY > camera.ViewportSize.Y then
        return false
    end

    -- print("🖱️ CLICK FÍSICO en: " .. guiObject.Name)
    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
    task.wait(0.1)
    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
    return true
end

local function tryClickButtonByName(text)
    local btn = findButtonGlobal(text)
    if btn then return clickGUIObject(btn) end
    return false
end

-- --- GUI PRINCIPAL ---
local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "MasterControlGUI_V463"; ScreenGui.Parent = playerGui; ScreenGui.ResetOnSpawn = false
local MainFrame = Instance.new("Frame"); MainFrame.Name = "MainFrame"; MainFrame.Size = UDim2.new(0, 250, 0, 280); MainFrame.Position = UDim2.new(0.5, -125, 0, 100);
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20); MainFrame.Draggable = true; MainFrame.Active = true; MainFrame.Parent = ScreenGui
local UICorner = Instance.new("UICorner"); UICorner.CornerRadius = UDim.new(0, 8); UICorner.Parent = MainFrame
local TitleLabel = Instance.new("TextLabel"); TitleLabel.Name = "Title"; TitleLabel.Size = UDim2.new(1, 0, 0, 30); TitleLabel.BackgroundColor3 = Color3.fromRGB(255, 215, 0); -- Dorado VIP
TitleLabel.TextColor3 = Color3.fromRGB(0, 0, 0); TitleLabel.Text = "V4.63 (VIP ONLY <"..VIP_THRESHOLD.."%)"; TitleLabel.Font = Enum.Font.SourceSansBold; TitleLabel.TextSize = 16; TitleLabel.Parent = MainFrame

local MasterToggleButton = Instance.new("TextButton"); MasterToggleButton.Size = UDim2.new(0.9, 0, 0, 40); MasterToggleButton.Position = UDim2.new(0.05, 0, 0, 40);
MasterToggleButton.BackgroundColor3 = Color3.fromRGB(170, 0, 0); MasterToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255); MasterToggleButton.Text = "Sistema VIP (OFF)"; MasterToggleButton.Font = Enum.Font.SourceSansBold; MasterToggleButton.TextSize = 18; MasterToggleButton.Parent = MainFrame

local StatusMode = Instance.new("TextLabel"); StatusMode.Text = "MODO: OFF"; StatusMode.Size = UDim2.new(0.9, 0, 0, 20); StatusMode.Position = UDim2.new(0.05, 0, 0, 90); StatusMode.BackgroundTransparency = 1; StatusMode.TextColor3 = Color3.fromRGB(255, 255, 100); StatusMode.TextXAlignment = Enum.TextXAlignment.Left; StatusMode.Parent = MainFrame
local AutoBuyCarInfoLabel = Instance.new("TextLabel"); AutoBuyCarInfoLabel.Text = "Cola VIP: 0"; AutoBuyCarInfoLabel.Size = UDim2.new(0.9, 0, 0, 40); AutoBuyCarInfoLabel.Position = UDim2.new(0.05, 0, 0, 115); AutoBuyCarInfoLabel.BackgroundTransparency = 1; AutoBuyCarInfoLabel.TextColor3 = Color3.fromRGB(255, 215, 0); AutoBuyCarInfoLabel.TextWrapped = true; AutoBuyCarInfoLabel.TextXAlignment = Enum.TextXAlignment.Left; AutoBuyCarInfoLabel.Parent = MainFrame
local AutoBuyCarStatusLabel = Instance.new("TextLabel"); AutoBuyCarStatusLabel.Text = "COMPRA: Inactiva"; AutoBuyCarStatusLabel.Size = UDim2.new(0.9, 0, 0, 20); 
AutoBuyCarStatusLabel.Position = UDim2.new(0.05, 0, 0, 160); 
AutoBuyCarStatusLabel.BackgroundTransparency = 1; AutoBuyCarStatusLabel.TextColor3 = Color3.fromRGB(255, 150, 150); AutoBuyCarStatusLabel.TextXAlignment = Enum.TextXAlignment.Left; AutoBuyCarStatusLabel.Parent = MainFrame

local RepairStatusLabel = Instance.new("TextLabel"); RepairStatusLabel.Text = "REPAIR: Inactivo"; RepairStatusLabel.Size = UDim2.new(0.9, 0, 0, 20); RepairStatusLabel.Position = UDim2.new(0.05, 0, 0, 185); RepairStatusLabel.BackgroundTransparency = 1; RepairStatusLabel.TextColor3 = Color3.fromRGB(255, 150, 150); RepairStatusLabel.TextXAlignment = Enum.TextXAlignment.Left; RepairStatusLabel.Parent = MainFrame
local SellStatusLabel = Instance.new("TextLabel"); SellStatusLabel.Text = "VENTA: Inactiva"; SellStatusLabel.Size = UDim2.new(0.9, 0, 0, 20); SellStatusLabel.Position = UDim2.new(0.05, 0, 0, 210); SellStatusLabel.BackgroundTransparency = 1; SellStatusLabel.TextColor3 = Color3.fromRGB(255, 150, 150); SellStatusLabel.TextXAlignment = Enum.TextXAlignment.Left; SellStatusLabel.Parent = MainFrame

local TrashManualButton = Instance.new("TextButton"); TrashManualButton.Text = "🗑️"; TrashManualButton.Size = UDim2.new(0.2, 0, 0, 25); TrashManualButton.Position = UDim2.new(0.75, 0, 0, 245); TrashManualButton.BackgroundColor3 = Color3.fromRGB(100, 30, 30); TrashManualButton.TextColor3 = Color3.fromRGB(255, 255, 255); TrashManualButton.Parent = MainFrame
local TrashLabel = Instance.new("TextLabel"); TrashLabel.Text = "Borrar Suelo:"; TrashLabel.Size = UDim2.new(0.6, 0, 0, 25); TrashLabel.Position = UDim2.new(0.1, 0, 0, 245); TrashLabel.BackgroundTransparency = 1; TrashLabel.TextColor3 = Color3.fromRGB(200, 200, 200); TrashLabel.TextXAlignment = Enum.TextXAlignment.Right; TrashLabel.Parent = MainFrame
TrashManualButton.MouseButton1Click:Connect(function() tryClickButtonByName("delete dropped parts") end)

local function updateGUI(mode)
    StatusMode.Text = "MODO: "..mode
    if mode == "BUY" then
        MasterToggleButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0); MasterToggleButton.Text = "Buscando VIPs..."
    elseif mode == "SELL" then
        MasterToggleButton.BackgroundColor3 = Color3.fromRGB(255, 150, 0); MasterToggleButton.Text = "VENDIENDO"
    elseif mode == "OFF" then
        MasterToggleButton.BackgroundColor3 = Color3.fromRGB(170, 0, 0); MasterToggleButton.Text = "Sistema VIP (OFF)"
    end
end
updateGUI(currentMode)

if CONFIRM_REMOTE then CONFIRM_REMOTE.OnClientInvoke = function() return true end end

-- --- DECLARACIÓN ADELANTADA ---
local startAutoSellLoop
local scanExistingCars
local startAutoRepair
local buyCar

-- >>> ESCUCHA DE EVENTOS CRÍTICA <<<
if NOTIFY_REMOTE then
    NOTIFY_REMOTE.OnClientEvent:Connect(function(text)
        if text == "Garage limit reached" then 
            print("!!! ALERTA: GARAJE LLENO. ABORTANDO COMPRA Y CAMBIANDO A VENTA !!!")
            currentMode = "SELL"
            updateGUI(currentMode)
             
            isRepairRunning = false 
            isAutoBuyCarBuying = false
             
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
-- LOGICA DE VENTA
-- =================================================================
startAutoSellLoop = function()
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
            SellStatusLabel.Text = "VENTA: "..modelName
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
                   pcall(function() setPaintEvent:FireServer(carInWorld, Color3.fromHSV(math.random(), 1, 1)) end)
                end
                task.wait(0.5)
                if promptVenta then pcall(fireproximityprompt, promptVenta, 0) end
                task.wait(2.5)
            end
        end
    end
    currentMode = "BUY"; updateGUI(currentMode); task.spawn(scanExistingCars)
end

-- =================================================================
-- LOGICA DE REPARACIÓN (V4.63 - Persistente)
-- =================================================================
startAutoRepair = function() 
    if currentMode ~= "BUY" then return end
     
    local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
     
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
    task.wait(1)
    RepairStatusLabel.Text = "REPAIR: Iniciando..."

    local carModel = targetCar 
    local character = player.Character
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then humanoid.Sit = false; humanoid.Jump = true end

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
        RepairStatusLabel.Text = "REPAIR: Limpiando..."
        for i=1,3 do if tryClickButtonByName("bring dropped parts") then task.wait(1.5); break end; task.wait(0.5) end
        for i=1,5 do
            if tryClickButtonByName("delete dropped parts") then
                RepairStatusLabel.Text = "REPAIR: Esperando borrado..."
                for j = 1, 8 do if #moveablePartsFolder:GetChildren() == 0 then break end; task.wait(1) end
                break
            end
            task.wait(0.5)
        end
    end
     
    RepairStatusLabel.Text = "REPAIR: Buscando componentes..."

    local carPartsEvent = carModel:WaitForChild("PartsEvent", 10)
    local engineBay = carModel:FindFirstChild("Body", true) 
    if not engineBay then
        local body = carModel:WaitForChild("Body", 5)
        if body then engineBay = body:WaitForChild("EngineBay", 5) end
    else
        engineBay = engineBay:WaitForChild("EngineBay", 5)
    end
     
    local carValuesFolder = carModel:FindFirstChild("Values", true)
    if not carValuesFolder then
        local vals = carModel:WaitForChild("Values", 5)
        if vals then carValuesFolder = vals:WaitForChild("Engine", 5) end
    else
        carValuesFolder = carValuesFolder:WaitForChild("Engine", 5)
    end
     
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
                if not data.Machine or not data.Part or not data.Part.Parent then
                    table.remove(partsBeingRepaired, i)
                    continue
                end
                 
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
     
    isRepairRunning = false; RepairStatusLabel.Text = "REPAIR: Terminado"
end

-- --- 9. LOGICA COMPRA ---
local function isCarInQueue(carModel)
    for _, item in ipairs(autoBuyCarQueue) do if item.car == carModel then return true end end
    return false
end

scanExistingCars = function()
    if currentMode ~= "BUY" then return end
    print("--- Escaneando VIPs (<"..VIP_THRESHOLD.."%)... ---")
    local found = 0
    for _, carModel in ipairs(VEHICLES_FOLDER:GetChildren()) do
        if carModel:IsA("Model") and not isCarInQueue(carModel) then
            local cd = carModel:FindFirstChild("ClickDetector")
            if cd then 
                local percent = 100 
                local wearValue = carModel:GetAttribute("Wear")
                if wearValue then percent = math.floor(wearValue * 100) end
                
                -- >>> FILTRO ABSOLUTO VIP <<<
                if percent <= VIP_THRESHOLD then
                    table.insert(autoBuyCarQueue, {car = carModel, percent = percent})
                    found = found + 1
                    print("💎 AUTO VIP ENCONTRADO: " .. percent .. "%")
                end
            end
        end
    end
    AutoBuyCarInfoLabel.Text = "Cola VIP: " .. #autoBuyCarQueue
    updateGUI(currentMode)
    if found == 0 then print("... No se encontraron VIPs. Esperando.") end
end

spawn(function()
    while true do
        task.wait(1)
        if isRepairRunning then AutoBuyCarStatusLabel.Text = "COMPRA: Esperando reparación..."; continue end
        if currentMode ~= "BUY" or #autoBuyCarQueue == 0 or isAutoBuyCarBuying then continue end

        isAutoBuyCarBuying = true
        
        -- >>> LOGICA: Entre los VIPs, el de menor % gana <<<
        table.sort(autoBuyCarQueue, function(a, b) 
            return a.percent < b.percent
        end)
        
        local item = table.remove(autoBuyCarQueue, 1)
        local carToBuy = item.car
         
        if not carToBuy or not carToBuy.Parent or not carToBuy:FindFirstChild("ClickDetector") then
            isAutoBuyCarBuying = false; if #autoBuyCarQueue == 0 then task.spawn(scanExistingCars) end; continue
        end

        -- >>> LIMPIEZA PRE-COMPRA <<<
        AutoBuyCarStatusLabel.Text = "COMPRA: Limpiando (10s)..."
        if tryClickButtonByName("delete dropped parts") then
            for k=1, CLEAN_DELAY do
                if currentMode ~= "BUY" then break end 
                AutoBuyCarStatusLabel.Text = "COMPRA: Limpiando ("..(CLEAN_DELAY-k).."s)..."
                task.wait(1)
            end
        end
         
        if currentMode ~= "BUY" then isAutoBuyCarBuying = false; continue end

        repeat task.wait(0.1) until player.Character
        local root = player.Character:FindFirstChild("HumanoidRootPart")
        if not root then isAutoBuyCarBuying = false; continue end
         
        root.CFrame = carToBuy:GetPivot() * CFrame.new(-8, 0, 0)
        AutoBuyCarStatusLabel.Text = "COMPRA: Intentando ("..item.percent.."%)..."
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
         
        if currentMode ~= "BUY" then isAutoBuyCarBuying = false; continue end
         
        if not purchaseSuccess and carToBuy.Parent then
            AutoBuyCarStatusLabel.Text = "COMPRA: Falló"
            task.wait(FAIL_DELAY)
            isAutoBuyCarBuying = false
            if #autoBuyCarQueue == 0 then task.spawn(scanExistingCars) end
            continue
        end

        AutoBuyCarStatusLabel.Text = "COMPRA: ¡Éxito!"
         
        local hoodPart = carToBuy:FindFirstChild("Misc") and carToBuy.Misc:FindFirstChild("Hood") and carToBuy.Misc.Hood:FindFirstChild("Detector") and carToBuy.Misc.Hood.Detector:FindFirstChild("ClickDetector")
        if hoodPart then fireclickdetector(hoodPart); task.wait(3) 
        else
             local anyCD = carToBuy:FindFirstChild("Hood", true)
             if anyCD then local cd = anyCD:FindFirstChildWhichIsA("ClickDetector", true); if cd then fireclickdetector(cd); task.wait(3) end end
        end
         
        if currentMode == "BUY" then startAutoRepair() end
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
            model = model:gsub("^%s*(.-)%s*$", "%1")
            
            -- >>> FILTRO EVENTOS VIP <<<
            if percent <= VIP_THRESHOLD then
                task.wait(0.5)
                local children = VEHICLES_FOLDER:GetChildren()
                local lastCar = children[#children]
                 
                if lastCar and lastCar:IsA("Model") and not isCarInQueue(lastCar) then
                    print("💎 EVENTO VIP: Auto nuevo detectado ("..percent.."%). A cola.")
                    table.insert(autoBuyCarQueue, {car = lastCar, percent = percent})  
                    AutoBuyCarInfoLabel.Text = "Cola VIP: " .. #autoBuyCarQueue
                end
            else
                print("Evento ignorado: Auto de " .. percent .. "% es basura (>10%).")
            end
        end
    end)
end

MasterToggleButton.MouseButton1Click:Connect(function()
    if currentMode == "OFF" then
        currentMode = "BUY"; task.spawn(scanExistingCars)
    else
        currentMode = "OFF"; isAutoBuyCarBuying = false; isRepairRunning = false; autoBuyCarQueue = {} 
    end
    updateGUI(currentMode)
end)

print("--- V4.63 (VIP ONLY) LISTA ---")
