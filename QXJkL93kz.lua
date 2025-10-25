-- ===============================================
-- 🛠️ 1. Carga de Librerías y Servicios
-- ===============================================

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local RunService = game:GetService("RunService")

-- ===============================================
-- ⚙️ 2. Configuración Principal del ESP
-- ===============================================

-- 🚨 LISTA DE LOS NOMBRES DE AUTOS QUE QUIERES EN EL MENÚ
local CarsToTrack = {
    "Onel costa",
    "BNV K3",
    -- "Agrega más autos aquí si descubres sus nombres"
}

-- Variables Globales de Control
local ESP_ENABLED = false
local activeESPs = {} 
local SelectedCars = {} 
local FOLDER_TO_SCAN = nil

-- Inicializa la tabla de selección, todo en 'false'
for _, carName in ipairs(CarsToTrack) do
    SelectedCars[carName] = false
end

-- Esperar a que exista la carpeta "Vehicles"
pcall(function()
    FOLDER_TO_SCAN = game.Workspace:WaitForChild("Vehicles", 60)
end)

if not FOLDER_TO_SCAN then
    Rayfield:Notify({Title = "Error", Content = "No se encontró la carpeta 'Vehicles' en Workspace."})
    return -- Detener el script
end

-- ===============================================
-- 🕵️ 3. FUNCIÓN DE IDENTIFICACIÓN
-- ===============================================

-- Esta función revisa dentro del modelo para encontrar su nombre real
local function GetVehicleFriendlyName(model)
    local friendlyName = model:GetAttribute("Model")
    
    -- Verificamos si el nombre es un UUID o un nombre real
    -- Si 'friendlyName' contiene un guion '-', probablemente es un UUID y lo ignoramos.
    if friendlyName and not string.find(friendlyName, "-") then
        return friendlyName -- Devuelve "BNV K3", "Onel costa", etc.
    end
    
    return nil -- No es un nombre amigable
end

-- ===============================================
-- 🖼️ 4. Creación de la Ventana Rayfield
-- ===============================================

local Window = Rayfield:CreateWindow({
    Name = "ESP de Vehículos (Selectivo)",
    LoadingTitle = "Cargando Script",
    LoadingSubtitle = "by 352ss",
    ConfigurationSaving = { Enabled = false }, 
    KeySystem = false,
})

-- Creamos la pestaña principal
local VisualsTab = Window:CreateTab("Visuales", 4483362458) 

-- ===============================================
-- 🎯 5. Lógica del ESP (Creación y Limpieza)
-- ===============================================

-- Función para crear el BillboardGui
local function CreateBillboardESP(targetModel, displayText)
    local partToTrack = targetModel.PrimaryPart or targetModel:FindFirstChildOfClass("Part")
    if not partToTrack then return nil end

    local bg = Instance.new("BillboardGui")
    bg.Size = UDim2.new(0, 150, 0, 50)
    bg.AlwaysOnTop = true
    bg.ExtentsOffset = Vector3.new(0, partToTrack.Size.Y / 2 + 1, 0)
    bg.Name = "RayfieldVehicleESP"
    bg.Parent = partToTrack

    local label = Instance.new("TextLabel")
    label.Text = displayText 
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 0) -- Color Amarillo (para autos en venta)
    label.Font = Enum.Font.SourceSansBold
    label.TextScaled = true
    label.Parent = bg
    
    return bg
end

-- Función para limpiar TODOS los ESPs (cuando se apaga el toggle)
local function CleanupAllESPs()
    for _, espElement in pairs(activeESPs) do
        if espElement and espElement.Parent then
            espElement:Destroy()
        end
    end
    activeESPs = {}
end

-- ===============================================
-- 🔗 6. Conexión de la Lógica a la Interfaz
-- ===============================================

-- --- SECCIÓN DE CONTROL GENERAL ---
VisualsTab:CreateSection("Control General") -- Esto es solo una etiqueta

-- Toggle principal (Llamado desde 'VisualsTab')
VisualsTab:CreateToggle({
    Name = "Activar ESP (Desguace)",
    CurrentValue = false, 
    Flag = "MasterESP_Toggle",
    Callback = function(Value)
        ESP_ENABLED = Value 
        
        if not Value then
            CleanupAllESPs()
            Rayfield:Notify({Title = "ESP Desactivado", Content = "Todos los visuales han sido eliminados."})
        else
             Rayfield:Notify({Title = "ESP Activado", Content = "Buscando vehículos del desguace."})
        end
    end,
})

-- --- SECCIÓN DE SELECCIÓN DE AUTOS ---
VisualsTab:CreateSection("Vehículos a Rastrear") -- Esto es solo una etiqueta

-- Crear un Toggle individual para cada auto en nuestra lista
for _, carName in ipairs(CarsToTrack) do
    
    -- (Llamado desde 'VisualsVab')
    VisualsTab:CreateToggle({
        Name = carName, -- "Onel costa", "BNV K3", etc.
        CurrentValue = false,
        Flag = "ESP_Track_" .. carName,
        Callback = function(Value)
            SelectedCars[carName] = Value
        end,
    })
    
end

-- ===============================================
-- 🔄 7. Bucle Principal de Escaneo
-- ===============================================

local function ScanForVehicles()
    if not ESP_ENABLED then return end

    -- 1. Escaneo y Actualización
    for _, model in ipairs(FOLDER_TO_SCAN:GetChildren()) do
        if model:IsA("Model") then
            
            -- 🛑 ¡DOBLE FILTRO! 🛑
            -- 1. No debe tener 'Owner'
            -- 2. Debe tener 'Junkyard = true'
            if model:GetAttribute("Owner") == nil and model:GetAttribute("Junkyard") == true then
            
                -- Es un auto del desguace. Intentamos obtener su nombre amigable.
                local friendlyName = GetVehicleFriendlyName(model)

                if friendlyName then
                    -- Si tiene un nombre (ej: "BNV K3")
                    local isSelected = SelectedCars[friendlyName]
                    
                    if isSelected and not activeESPs[model] then
                        -- Si lo queremos ver Y no tiene ESP, lo creamos
                        local newESP = CreateBillboardESP(model, friendlyName)
                        if newESP then
                            activeESPs[model] = newESP
                            
                            model.AncestryChanged:Connect(function(_, newParent)
                                if not newParent or newParent.Name == "Debris" then
                                    if activeESPs[model] then
                                        activeESPs[model]:Destroy()
                                        activeESPs[model] = nil
                                    end
                                end
                            end)
                        end
                    elseif not isSelected and activeESPs[model] then
                        -- Si NO lo queremos ver, PERO tiene ESP, lo destruimos
                        activeESPs[model]:Destroy()
                        activeESPs[model] = nil
                    end
                end
            
            end
        end
    end

    -- 2. Limpieza de ESPs (para autos que fueron destruidos)
    for model, espElement in pairs(activeESPs) do
        if not model.Parent or not espElement.Parent then
            if espElement.Parent then espElement:Destroy() end
            activeESPs[model] = nil
        end
    end
end

RunService.Stepped:Connect(ScanForVehicles)
