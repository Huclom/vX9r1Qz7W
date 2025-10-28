-- 1. Inicialización de Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- 2. Creación de la Ventana
local Window = Rayfield:CreateWindow({
    Name = "Dataloss",
    LoadingTitle = "Cargando Rayfield...",
    ConfigurationSaving = true, 
    FileName = "Mi_Configuracion_Rayfield" 
})

-- 3. Adición de la Pestaña
local Tab = Window:CreateTab("Funciones", 4483244820) 

-- 4. FUNCIÓN DE DATA LOSS (Desconexión Forzada)
local function KickPlayer()
    game.Players.LocalPlayer:Kick("¡Conexión terminada! Supuesto 'Data Loss' activado.")
end

-- 5. Creación del Botón de Data Loss
Tab:CreateButton({
    Name = "Forzar Data Loss (Kick)",
    Description = "Desconecta al jugador rápidamente. Úsalo bajo tu propio riesgo.",
    Callback = function()
        Rayfield:Notify({
            Title = "PELIGRO",
            Content = "¡El Data Loss se ejecutará en 3 segundos!",
            Duration = 3,
            Color = Color3.fromRGB(255, 0, 0) 
        })
        
        -- Espera 3 segundos (task.wait() es preferido sobre wait())
        task.wait(3) 
        KickPlayer()
    end,
})

-- 6. Botones de ejemplo (puedes mantener los anteriores si quieres)
Tab:CreateButton({
    Name = "Salto Alto (Jump Power)",
    Callback = function()
        game.Players.LocalPlayer.Character.Humanoid.JumpPower = 100
    end,
})


-- 7. Cargar la configuración guardada
Rayfield:LoadConfiguration()
