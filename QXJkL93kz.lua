-- ===============================================
-- 🛠️ 1. Carga de Librerías y Servicios
-- ===============================================

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local RunService = game:GetService("RunService")

-- ===============================================
-- ⚙️ 2. Configuración Principal del ESP
-- ===============================================

local ESP_ENABLED = false
local DEBUG_MODE = false 
local activeESPs = {} 
local FOLDER_TO_SCAN = nil

pcall(function()
    FOLDER_TO_SCAN = game.Workspace:WaitForChild("Vehicles", 60)
end)

if not FOLDER_TO_SCAN then
    Rayfield:Notify({Title = "Error", Content = "No se encontró la carpeta 'Vehicles' en Workspace."})
    return 
end

-- ===============================================
-- 🖼️ 3. Creación de la Ventana Rayfield
-- ===============================================

local Window = Rayfield:CreateWindow({
    Name = "ESP de Vehículos (Prueba 3)",
    LoadingTitle = "Cargando Script",
    LoadingSubtitle = "by aavvss",
    ConfigurationSaving = { Enabled = false }, 
    KeySystem = false,
})

local VisualsTab = Window:CreateTab("Visuales", 4483362458) 

-- ===============================================
-- 🎯 4. Lógica del ESP (¡CORREGIDA!)
-- ===============================================

-- 🛑 ¡NUEVA FUNCIÓN DE BÚSQUEDA ROBUSTA! 🛑
-- Esta función buscará recursivamente hasta encontrar una BasePart
local function FindAnyPart(instance)
    if instance:IsA("BasePart") then
        return instance -- ¡Encontrada!
    end

    -- Si no es una parte, mira a sus hijos
    for _, child in ipairs(instance:GetChildren()) do
        local foundPart = FindAnyPart(child) -- Llama a la función de nuevo para este hijo
        if foundPart then
            return foundPart -- Devuelve la parte encontrada en la recursión
        end
    end
    
    return nil -- No se encontró nada en esta rama
end

-- Función para crear el BillboardGui (¡MODIFICADA!)
local function CreateBillboardESP(targetModel)
    
    -- Usamos nuestra nueva función de búsqueda
    local partToTrack = targetModel.PrimaryPart or FindAnyPart(targetModel)

    if not partToTrack then
        if DEBUG_MODE then
            warn("[DEBUG] Falla en CreateBillboardESP: No se encontró NINGUNA 'BasePart' (búsqueda recursiva): " .. targetModel.Name)
        end
        return nil 
    end
    
    if DEBUG_MODE then
        print("[DEBUG] CreateBillboardESP: 'partToTrack' encontrada: " .. partToTrack:GetFullName())
    end

    local bg = Instance.new("BillboardGui")
    bg.Size = UDim2.new(0, 150, 0, 50)
    bg.AlwaysOnTop = true
    bg.ExtentsOffset = Vector3.new(0, 1, 0) 
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
    label.TextColor3 = Color3.new(1, 1, 0) 
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

VisualsTab:CreateSection("Control General") 

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
-- 🔄 6. Bucle Principal de Escaneo (Sin cambios)
-- ===============================================

local function ScanForVehicles()
    if not ESP_ENABLED then return end

    for _, model in ipairs(FOLDER_TO_SCAN:GetChildren()) do
        if model:IsA("Model") then
            
            if DEBUG_MODE and not activeESPs[model] then -- Solo imprime para autos nuevos
                print("[DEBUG] Escaneando: " .. model.Name)
            end

            -- Filtro por 'Junkyard'
            if model:GetAttribute("Junkyard") == true then
            
                if DEBUG_MODE and not activeESPs[model] then
                    print("[DEBUG] Modelo " .. model.Name .. " es 'Junkyard'. Creando ESP...")
                end

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
                if activeESPs[model] then
                    activeESPs[model]:Destroy()
                    activeESPs[model] = nil
                end
            end
        end
    end

    -- Limpieza
    for model, espElement in pairs(activeESPs) do
        if not model.Parent or not espElement.Parent then
            if espElement.Parent then espElement:Destroy() end
            activeESPs[model] = nil
        end
    end
end

RunService.Stepped:Connect(ScanForVehicles)
