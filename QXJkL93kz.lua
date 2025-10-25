-- ===============================================
-- 🛠️ 1. Carga de Librerías y Servicios
-- ===============================================

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local RunService = game:GetService("RunService")

-- ===============================================
-- ⚙️ 2. Configuración Principal del ESP
-- ===============================================

-- Variables Globales de Control
local ESP_ENABLED = false
local activeESPs = {} 
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
-- 🖼️ 3. Creación de la Ventana Rayfield
-- ===============================================

local Window = Rayfield:CreateWindow({
    Name = "ESP de Vehículos (Prueba)",
    LoadingTitle = "Cargando Script",
    LoadingSubtitle = "by popeye",
    ConfigurationSaving = { Enabled = false }, 
    KeySystem = false,
})

-- Creamos la pestaña principal
local VisualsTab = Window:CreateTab("Visuales", 4483362458) 

-- ===============================================
-- 🎯 4. Lógica del ESP (Creación y Limpieza)
-- ===============================================

-- Función para crear el BillboardGui
local function CreateBillboardESP(targetModel)
    local partToTrack = targetModel.PrimaryPart or targetModel:FindFirstChildOfClass("Part")
    if not partToTrack then return nil end

    local bg = Instance.new("BillboardGui")
    bg.Size = UDim2.new(0, 150, 0, 50)
    bg.AlwaysOnTop = true
    bg.ExtentsOffset = Vector3.new(0, partToTrack.Size.Y / 2 + 1, 0)
    bg.Name = "RayfieldVehicleESP"
    bg.Parent = partToTrack
    
    -- Para la prueba, mostraremos el atributo "Model", sea lo que sea
    local modelName = targetModel:GetAttribute("Model") or "???"
    
    -- Si es un UUID (contiene '-'), lo acortamos
    if type(modelName) == "string" and string.find(modelName, "-") then
        modelName = modelName:sub(1, 8) -- Muestra solo los primeros 8 caracteres
    end

    local label = Instance.new("TextLabel")
    label.Text = tostring(modelName) -- Muestra el nombre (ej: "BNV K3" o "19b99dde")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 0) -- Color Amarillo
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
-- 🔗 5. Conexión de la Lógica a la Interfaz
-- ===============================================

VisualsTab:CreateSection("Control General") -- Etiqueta visual

-- Toggle principal (Llamado desde 'VisualsTab')
VisualsTab:CreateToggle({
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

-- ===============================================
-- 🔄 6. Bucle Principal de Escaneo
-- ===============================================

local function ScanForVehicles()
    if not ESP_ENABLED then return end

    -- 1. Escaneo y Actualización
    for _, model in ipairs(FOLDER_TO_SCAN:GetChildren()) do
        if model:IsA("Model") then
            
            -- 🛑 ¡FILTRO ÚNICO Y SIMPLIFICADO! 🛑
            -- Si el auto NO tiene 'Owner', es un auto en venta.
            if model:GetAttribute("Owner") == nil then
            
                -- Si es un auto en venta y NO tiene ESP, lo creamos.
                if not activeESPs[model] then
                    local newESP = CreateBillboardESP(model)
                    if newESP then
                        activeESPs[model] = newESP
                        
                        -- Conexión para limpiar si el auto se destruye
                        model.AncestryChanged:Connect(function(_, newParent)
                            if not newParent or newParent.Name == "Debris" then
                                if activeESPs[model] then
                                    activeESPs[model]:Destroy()
                                    activeESPs[model] = nil
                                end
                            end
end)
                    end
                end
            
            else
                -- Si el auto SÍ tiene 'Owner', nos aseguramos de que NO tenga ESP.
                -- (Esto limpiará el ESP si alguien compra el auto)
                if activeESPs[model] then
                    activeESPs[model]:Destroy()
                    activeESPs[model] = nil
                end
            end
        end
    end

    -- 2. Limpieza (por si acaso un auto se borró de otra forma)
    for model, espElement in pairs(activeESPs) do
        if not model.Parent or not espElement.Parent then
            if espElement.Parent then espElement:Destroy() end
            activeESPs[model] = nil
        end
    end
end

-- Usamos 'Stepped' para un escaneo constante (cada fotograma)
RunService.Stepped:Connect(ScanForVehicles)
