-- 1. Inicialización de Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- 2. Creación de la Ventana
local Window = Rayfield:CreateWindow({
    Name = "Mi Menú de Pruebas Rayfield",
    LoadingTitle = "Cargando Rayfield...",
    ConfigurationSaving = true, 
    FileName = "Mi_Configuracion_Rayfield" 
})

-- 3. Adición de la Pestaña
local Tab = Window:CreateTab("Funciones", 4483244820) 

-- 4. Pruebas de Elementos
-- Botón (Salto Alto)
Tab:CreateButton({
    Name = "Salto Alto (Jump Power)",
    Callback = function()
        game.Players.LocalPlayer.Character.Humanoid.JumpPower = 100
        Rayfield:Notify({
            Title = "Acción Ejecutada",
            Content = "¡El poder de salto ha sido cambiado a 100!",
            Duration = 4
        })
    end,
})

-- Interruptor (Súper Velocidad)
Tab:CreateToggle({
    Name = "Súper Velocidad (Speed)",
    CurrentValue = false,
    Flag = "speedHack",
    Callback = function(Value)
        if Value then
            game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 50 
        else
            game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 16
        end
    end,
})

-- Deslizador (Transparencia)
Tab:CreateSlider({
    Name = "Transparencia del Personaje",
    Range = {0, 1},
    Increment = 0.1,
    Suffix = " de Opacidad",
    CurrentValue = 0,
    Flag = "transparencySlider", 
    Callback = function(Value)
        for _, part in ipairs(game.Players.LocalPlayer.Character:GetChildren()) do
            if part:IsA("BasePart") then
                part.Transparency = Value
            end
        end
    end,
})

-- Importante: Cargar la configuración guardada al final
Rayfield:LoadConfiguration()
