-- ===============================================
-- 🛠️ 1. Carga de Librerías y Servicios
-- ===============================================

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local RunService = game:GetService("RunService")

-- ===============================================
-- ⚙️ 2. Configuración Principal del ESP
-- ===============================================

-- 🚨 LISTA DE LOS NOMBRES DE AUTOS QUE QUIERES EN EL MENÚ
-- (Estos son los valores del Atributo "Model" que encontramos)
local CarsToTrack = {
    "Onel costa",
    "BNV K3",
    -- "Agrega más autos aquí"
}

-- Variables Globales de Control
local ESP_ENABLED = false
local activeESPs = {} -- Rastrea los ESPs activos
local SelectedCars = {} -- Tabla que guarda los autos seleccionados (ej: SelectedCars["Onel costa"] = true)
local FOLDER_TO_SCAN = nil

-- Inicializa la tabla de selección
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
    if friendlyName then
        return friendlyName
    end
    return nil
end

-- ===============================================
-- 🖼️ 4. Creación de la Ventana Rayfield
-- ===============================================

local Window = Rayfield:CreateWindow({
    Name = "ESP de Vehículos (Selectivo)",
    LoadingTitle = "Cargando Script",
    LoadingSubtitle = "by Rev",
    ConfigurationSaving = { Enabled = false }, 
    KeySystem = false,
})

local VisualsTab = Window:CreateTab("Visuales", 4483362458) 
local ESPSettingsSection = VisualsTab:CreateSection("Control General")

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
    label.Text = displayText -- Muestra "BNV K3"
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

-- Toggle principal para encender o apagar todo el sistema
ESPSettingsSection:CreateToggle({
    Name = "Activar ESP (Autos en Venta)",
    CurrentValue = false, 
    Flag = "MasterESP_Toggle",
    Callback = function(Value)
        ESP_ENABLED = Value 
        
        if not Value then
            CleanupAllESPs()
            Rayfield:Notify({Title = "ESP Desactivado", Content = "Todos los visuales han sido eliminados."})
        else
             Rayfield:Notify({Title = "ESP Activado", Content = "Buscando vehículos sin dueño."})
        end
    end,
})

-- --- SECCIÓN DE SELECCIÓN DE AUTOS ---
local CarSelectionSection = VisualsTab:CreateSection("Vehículos a Rastrear")

-- Crear un Toggle individual para cada auto en nuestra lista
for _, carName in ipairs(CarsToTrack) do
    
    CarSelectionSection:CreateToggle({
        Name = carName, -- "Onel costa", "BNV K3", etc.
        CurrentValue = false,
        Flag = "ESP_Track_" .. carName,
        Callback = function(Value)
            -- Actualiza nuestra tabla de autos seleccionados
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
            
            -- 🛑 ¡NUEVO FILTRO! 🛑
            -- Verificamos si el auto tiene el atributo "Owner".
            if model:GetAttribute("Owner") == nil then
            
                -- Si no tiene dueño, es un auto en venta. Procedemos a identificarlo.
                local friendlyName = GetVehicleFriendlyName(model)

                if friendlyName then
                    -- Verificamos si este auto está en nuestra lista de seleccionados
                    local isSelected = SelectedCars[friendlyName]
                    
                    if isSelected and not activeESPs[model] then
                        -- Si está seleccionado y NO tiene un ESP, lo creamos
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
                        -- Si NO está seleccionado, PERO tiene un ESP, lo destruimos
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
