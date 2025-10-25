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
local DEBUG_MODE = false -- Variable para el modo de depuración
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
    Name = "ESP de Vehículos (Prueba 2)",
    LoadingTitle = "Cargando Script",
    LoadingSubtitle = "by [Tu 25]",
    ConfigurationSaving = { Enabled = false }, 
    KeySystem = false,
})

local VisualsTab = Window:CreateTab("Visuales", 4483362458) 

-- ===============================================
-- 🎯 4. Lógica del ESP (Creación y Limpieza)
-- ===============================================

-- Función para crear el BillboardGui
local function CreateBillboardESP(targetModel)
    -- Buscamos recursivamente (el 'true') cualquier 'BasePart'
    local partToTrack = targetModel:FindFirstChildOfClass("BasePart", true) 

    if not partToTrack then
        if DEBUG_MODE then
            warn("[DEBUG] Falla en CreateBillboardESP: No se encontró ninguna 'BasePart' en el modelo: " .. targetModel.Name)
        end
        return nil -- Falla silenciosa si no hay debug
    end

    local bg = Instance.new("BillboardGui")
    bg.Size = UDim2.new(0, 150, 0, 50)
    bg.AlwaysOnTop = true
    bg.ExtentsOffset = Vector3.new(0, 1, 0) -- Lo ponemos 1 stud arriba de la parte que encontró
    bg.Name = "RayfieldVehicleESP"
    bg.Parent = partToTrack
    
    local modelName = targetModel:GetAttribute("Model") or "???"
    if type(modelName) == "string" and string.find(modelName, "-") then
        modelName = modelName:sub(1, 8) 
    end

    local label = Instance.new("TextLabel")
    label.Text = tostring(modelName)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 0) -- Color Amarillo
    label.Font = Enum.Font.SourceSansBold
    label.TextScaled = true
    label.Parent = bg
    
    return bg
end

-- Función para limpiar TODOS los ESPs
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

-- Toggle principal
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

-- Toggle de Depuración
VisualsTab:CreateToggle({
    Name = "Modo Depuración (Abre F9)",
    CurrentValue = false, 
    Flag = "Debug_Toggle",
    Callback = function(Value)
        DEBUG_MODE = Value
        if Value then
            Rayfield:Notify({Title = "DEBUG ACTIVADO", Content = "Revisa la consola (F9) para ver el log."})
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
            
            if DEBUG_MODE then
                print("[DEBUG] Escaneando: " .. model.Name)
            end

            -- 🛑 ¡NUEVO FILTRO MÁS FIABLE! 🛑
            -- Si el auto SÍ tiene 'Junkyard = true'
            if model:GetAttribute("Junkyard") == true then
            
                if DEBUG_MODE then
                    print("[DEBUG] Modelo " .. model.Name .. " es 'Junkyard'. Creando ESP...")
                end

                -- Si es un auto del desguace y NO tiene ESP, lo creamos.
                if not activeESPs[model] then
                    local newESP = CreateBillboardESP(model)
                    if newESP then
                        if DEBUG_MODE then
                            print("[DEBUG] ESP creado exitosamente para " .. model.Name)
                        end
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
                end
            
            else
                -- Si el auto NO es 'Junkyard', nos aseguramos de que NO tenga ESP.
                if DEBUG_MODE then
                    print("[DEBUG] Modelo " .. model.Name .. " NO es 'Junkyard'. Ignorando.")
                end
                
                if activeESPs[model] then
                    activeESPs[model]:Destroy()
                    activeESPs[model] = nil
                end
            end
        end
    end

    -- 2. Limpieza
    for model, espElement in pairs(activeESPs) do
        if not model.Parent or not espElement.Parent then
            if espElement.Parent then espElement:Destroy() end
            activeESPs[model] = nil
        end
    end
end

RunService.Stepped:Connect(ScanForVehicles)
