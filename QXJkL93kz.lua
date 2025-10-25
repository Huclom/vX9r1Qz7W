-- ===============================================
-- 🛠️ 1. Carga de Librerías y Servicios
-- ===============================================

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local RunService = game:GetService("RunService")

-- ===============================================
-- ⚙️ 2. Configuración Principal del ESP
-- ===============================================

-- 🚨 LISTA DE LOS NOMBRES DE AUTOS QUE QUIERES EN EL DROPDOWN
-- (Estos son los valores del Atributo "Model" que encontramos)
local CarsToTrack = {
    "Onel costa",
    "BNV K3",
    -- "Agrega más autos aquí"
}

-- Variables Globales de Control
local ESP_ENABLED = false
local activeESPs = {} -- Rastrea los ESPs activos
local SelectedCars = {} -- Tabla que guarda los nombres amigables que seleccionaste en el dropdown
local FOLDER_TO_SCAN = nil

-- Esperar a que exista la carpeta "Vehicles"
pcall(function()
    FOLDER_TO_SCAN = game.Workspace:WaitForChild("Vehicles", 60)
end)

if not FOLDER_TO_SCAN then
    Rayfield:Notify({Title = "Error", Content = "No se encontró la carpeta 'Vehicles' en Workspace."})
    return -- Detener el script
end

-- ===============================================
-- 🕵️ 3. FUNCIÓN DE IDENTIFICACIÓN (Actualizada)
-- ===============================================

-- Esta función revisa dentro del modelo para encontrar su nombre real
local function GetVehicleFriendlyName(model)
    
    -- MÉTODO A (Confirmado por tu captura): Buscar un Atributo
    -- Buscamos el atributo llamado "Model"
    local friendlyName = model:GetAttribute("Model")
    
    if friendlyName then
        return friendlyName -- Devuelve "BNV K3", "Onel costa", etc.
    end

    return nil -- No se pudo identificar el auto
end

-- ===============================================
-- 🖼️ 4. Creación de la Ventana Rayfield
-- ===============================================

local Window = Rayfield:CreateWindow({
    Name = "ESP de Vehículos (Selectivo)",
    LoadingTitle = "Cargando Script",
    LoadingSubtitle = "by [Tu Alias]",
    ConfigurationSaving = { Enabled = false }, 
    KeySystem = false,
})

local VisualsTab = Window:CreateTab("Visuales", 4483362458) 
local ESPSettingsSection = VisualsTab:CreateSection("Control del ESP")

-- ===============================================
-- 🎯 5. Lógica del ESP (Creación y Limpieza)
-- ===============================================

-- Función para crear el BillboardGui
local function CreateBillboardESP(targetModel, displayText)
    local partToTrack = targetModel.PrimaryPart or targetModel:FindFirstChildOfClass("Part")
    if not partToTrack then return nil end

    local bg = Instance.new("BillboardGui")
    bg.Size = UDim2.new(0, 150, 0, 50)
    bg.AlwaysOnTop = true -- Se ve a través de las paredes
    bg.ExtentsOffset = Vector3.new(0, partToTrack.Size.Y / 2 + 1, 0)
    bg.Name = "RayfieldVehicleESP"
    bg.Parent = partToTrack

    local label = Instance.new("TextLabel")
    label.Text = displayText -- Muestra "BNV K3"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(0, 1, 1) -- Color Cyan
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
VisualsTab:CreateToggle({
    Name = "Activar ESP",
    CurrentValue = false, 
    Flag = "MasterESP_Toggle",
    Callback = function(Value)
        ESP_ENABLED = Value 
        
        if not Value then
            CleanupAllESPs()
            Rayfield:Notify({Title = "ESP Desactivado", Content = "Todos los visuales han sido eliminados."})
        else
             Rayfield:Notify({Title = "ESP Activado", Content = "Buscando vehículos seleccionados."})
        end
    end,
})

-- Dropdown de Selección Múltiple
VisualsTab:CreateMultiDropdown({
    Name = "Seleccionar Vehículos a Rastrear",
    Options = CarsToTrack, -- Usa la lista de la sección 2
    CurrentOption = {},
    Flag = "VehicleSelectionDropdown",
    Callback = function(SelectedOptions)
        SelectedCars = SelectedOptions
    end,
})

-- ===============================================
-- 🔄 7. Bucle Principal de Escaneo
-- ===============================================

local function ScanForVehicles()
    if not ESP_ENABLED then return end

    -- 1. Escaneo y Actualización
    for _, model in ipairs(FOLDER_TO_SCAN:GetChildren()) do
        if model:IsA("Model") then
            local friendlyName = GetVehicleFriendlyName(model)

            if friendlyName then
                local isSelected = table.find(SelectedCars, friendlyName)
                
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

    -- 2. Limpieza de ESPs (para autos que fueron destruidos)
    for model, espElement in pairs(activeESPs) do
        if not model.Parent or not espElement.Parent then
            if espElement.Parent then espElement:Destroy() end
            activeESPs[model] = nil
        end
    end
end

RunService.Stepped:Connect(ScanForVehicles)
