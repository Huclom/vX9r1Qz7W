local ui = loadstring(game:HttpGet('https://raw.githubusercontent.com/Singularity5490/rbimgui-2/main/rbimgui-2.lua'))()
local mainWindow = ui.new({
    text = 'Lootify By Pancakq',
    size = UDim2.new(0, 650, 0, 400)
})
mainWindow.open()

local autoFarmTab = mainWindow.new({
    text = 'AutoFarm',
    padding = Vector2.new(10, 10)
})

local autoKillEnabled = false
local lastActionTime = os.clock()

local dungeonList = {
    {
        name = '[...] None',
        id = nil
    },
    {
        name = '01. Starter',
        id = 101002
    },
    {
        name = '01. Medium',
        id = 101003
    },
    {
        name = '01. Hard',
        id = 101004
    },
    {
        name = '01. Extreme',
        id = 101005
    },
    {
        name = '01. Final Boss',
        id = 101006
    },
    {
        name = '02. Starter',
        id = 101007
    },
    {
        name = '02. Medium',
        id = 101008
    },
    {
        name = '02. Hard',
        id = 101009
    },
    {
        name = '02. Extreme',
        id = 101010
    },
    {
        name = '02. Final Boss',
        id = 101011
    },
    {
        name = '02. Secret Boss',
        id = 101012
    },
    {
        name = '03. Starter',
        id = 101013
    },
    {
        name = '03. Medium',
        id = 101014
    },
    {
        name = '03. Hard',
        id = 101015
    },
    {
        name = '03. Extreme',
        id = 101016
    },
    {
        name = '03. Final Boss',
        id = 101017
    }
}

local priorityList = {}

local function findClosestEnemy()
    local closestDistance, closestEnemy = math.huge, nil
    local playerRoot = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild('HumanoidRootPart')
    
    if not playerRoot then
        return nil
    end
    
    for _, enemy in pairs(workspace:FindFirstChild('EnemyFolder'):GetChildren()) do
        if enemy:IsA('Model') and enemy:FindFirstChild('HumanoidRootPart') and enemy:FindFirstChild('Humanoid') and enemy.Humanoid.Health > 0 then
            local distance = (enemy.HumanoidRootPart.Position - playerRoot.Position).Magnitude
            if distance < closestDistance then
                closestDistance = distance
                closestEnemy = enemy
            end
        end
    end
    
    return closestEnemy
end

local tweenService = game:GetService('TweenService')

local function moveToTarget(playerRoot, target)
    local targetCFrame = target.HumanoidRootPart.CFrame * CFrame.new(0, 0, 5)
    local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = tweenService:Create(playerRoot, tweenInfo, {
        CFrame = targetCFrame
    })
    tween:Play()
end

local function enemiesExist()
    local enemyFolder = workspace:FindFirstChild('EnemyFolder')
    if not enemyFolder then
        return false
    end
    
    for _, enemy in pairs(enemyFolder:GetChildren()) do
        if enemy:IsA('Model') and enemy:FindFirstChild('Humanoid') and enemy.Humanoid.Health > 0 then
            return true
        end
    end
    
    return false
end

local dungeonPositions = {
    [101002] = Vector3.new(37.09999999999991, 101.35, -306.84),
    [101003] = Vector3.new(14.54000000000002, 101.34999999999991, -306.6),
    [101004] = Vector3.new(-15.3900000000001, 101.35, -307.2),
    [101005] = Vector3.new(-37.099999999999994, 101.35, -306.47),
    [101006] = Vector3.new(-2.29, 102.22, -274.05999999999995),
    [101007] = Vector3.new(-718.27, 55.77, 1270.1),
    [101008] = Vector3.new(-781.76, 56.08, 1320.87),
    [101009] = Vector3.new(-825.8899999999999, 59.6400000000001, 1408.4799999999996),
    [101010] = Vector3.new(-923.6300000000001, 56.75, 1384.1599999999999),
    [101011] = Vector3.new(-1049.83, 56.25999999999999, 1313.55),
    [101012] = Vector3.new(-893.3, 61.21000000000001, 1479.94),
    [101013] = Vector3.new(1776.08, -133.5, 2860.93),
    [101014] = Vector3.new(1378.2399999999998, -129.25, 2808.32),
    [101015] = Vector3.new(2014.44, -131.98, 2759.540000000001),
    [101016] = Vector3.new(1366.6400000000003, -127.01, 2824.76),
    [101017] = Vector3.new(1992.17, -65.05, 2805.37)
}

local function teleportToDungeon(dungeonId)
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:FindFirstChild('HumanoidRootPart')
    
    if humanoidRootPart and dungeonPositions[dungeonId] then
        humanoidRootPart.CFrame = CFrame.new(dungeonPositions[dungeonId])
        print('Teleported to dungeon:', dungeonId)
    else
        print('Invalid dungeon ID or missing HumanoidRootPart')
    end
end

local function tryNextDungeon()
    for _, dungeonInfo in ipairs(priorityList) do
        teleportToDungeon(dungeonInfo.id)
        wait(1)
        
        local args = {
            dungeonInfo.id
        }
        game:GetService('ReplicatedStorage'):WaitForChild('Remotes'):WaitForChild('Region'):WaitForChild('EnterRegion'):FireServer(unpack(args))
        
        print('Attempting to enter:', dungeonInfo.name)
        wait(8)
        
        if enemiesExist() then
            print('Enemies detected. Proceeding with Auto Kill.')
            return
        else
            print('No enemies detected in:', dungeonInfo.name, '. Trying next priority...')
        end
    end
    print('All selected dungeons attempted. Restarting from priority 1.')
end

local function toggleAutoKill(enabled)
    autoKillEnabled = enabled
    local player = game.Players.LocalPlayer
    local respawnDelay = 5
    local noEnemiesTimeout = 8
    local noEnemiesCounter = 0
    
    if autoKillEnabled then
        print('Auto Kill enabled')
        spawn(function()
            while autoKillEnabled do
                pcall(function()
                    local character = player.Character or player.CharacterAdded:Wait()
                    local humanoid = character:WaitForChild('Humanoid', 5)
                    local humanoidRootPart = character:WaitForChild('HumanoidRootPart', 5)
                    
                    if humanoid.Health <= 0 then
                        print('-- Player is dead. Waiting to respawn...')
                        repeat
                            wait(1)
                            humanoid = player.Character:WaitForChild('Humanoid', 5)
                        until humanoid.Health > 0
                        print('-- Respawn detected. Waiting before resuming attacks...')
                        wait(respawnDelay)
                    end
                    
                    if not humanoidRootPart or not humanoid then
                        print('-- Tool or HumanoidRootPart not found, retrying...')
                        return
                    end
                    
                    local tool = character:FindFirstChildOfClass('Tool') or player.Backpack:FindFirstChildOfClass('Tool')
                    
                    if not tool then
                        print('-- Tool not found, retrying...')
                        return
                    end
                    
                    if tool.Parent ~= character then
                        tool.Parent = character
                        wait(0.5)
                    end
                    
                    local target = findClosestEnemy()
                    
                    if target then
                        print('-- Enemy found, attacking immediately')
                        moveToTarget(humanoidRootPart, target)
                        tool:Activate()
                        noEnemiesCounter = 0
                    else
                        print('-- No target found, checking for enemies...')
                    end
                end)
                wait(0.1)
            end
        end)
        
        spawn(function()
            while autoKillEnabled do
                if not enemiesExist() then
                    noEnemiesCounter = noEnemiesCounter + 1
                    if noEnemiesCounter >= noEnemiesTimeout then
                        print('No enemies detected for 8 seconds. Attempting to join next dungeon in priority order...')
                        tryNextDungeon()
                        noEnemiesCounter = 0
                    end
                else
                    noEnemiesCounter = 0
                end
                wait(1)
            end
        end)
    else
        print('Auto Kill disabled')
    end
end

local autoKillSwitch = autoFarmTab.new('switch', {
    text = 'Auto Kill',
    tooltip = 'Smoothly tethers behind enemies and attacks them automatically.'
})
autoKillSwitch.set(false)
autoKillSwitch.event:Connect(toggleAutoKill)

local priorityDropdowns = {}
for i = 1, 10 do
    local dropdown = autoFarmTab.new('dropdown', {
        text = 'Priority ' .. i,
        tooltip = 'Select dungeon for priority ' .. i
    })
    
    for _, dungeonInfo in ipairs(dungeonList) do
        dropdown.new(dungeonInfo.name)
    end
    
    dropdown.event:Connect(function(selectedName)
        for _, dungeonInfo in ipairs(dungeonList) do
            if dungeonInfo.name == selectedName then
                priorityList[i] = {
                    name = selectedName,
                    id = dungeonInfo.id
                }
                print('Set priority ' .. i .. ' to dungeon:', selectedName)
                break
            end
        end
    end)
    
    table.insert(priorityDropdowns, dropdown)
end

autoFarmTab.new('label', {
    text = 'Do not TP to dungeons across different islands as it may ban you.',
    color = Color3.new(1, 0, 0)
})

autoFarmTab.new('label', {
    text = 'Wait 10 seconds then it will TP you :3',
    color = Color3.new(1, 0, 0)
})

local autoTab = mainWindow.new({
    text = 'Auto',
    padding = Vector2.new(10, 10)
})

local autoPickupRelicSwitch = autoTab.new('switch', {
    text = 'Auto Pickup Ancient Relic',
    tooltip = 'Automatically picks up Ancient Relics by teleporting and interacting with them.'
})
autoPickupRelicSwitch.set(false)

local player = game.Players.LocalPlayer
local autoPickupRelicEnabled = false

local function tweenToPosition(part)
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild('HumanoidRootPart')
    
    if humanoidRootPart then
        local targetCFrame = part.CFrame + Vector3.new(0, 3, 0)
        local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
        local tween = tweenService:Create(humanoidRootPart, tweenInfo, {
            CFrame = targetCFrame
        })
        tween:Play()
        tween.Completed:Wait()
    end
end

local function interactWithPrompt(prompt)
    print('Interacting with ProximityPrompt at:', prompt.Parent.Name)
    fireproximityprompt(prompt)
    wait(0.5)
end

local function scanForRelics()
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild('HumanoidRootPart')
    local originalPosition = humanoidRootPart.CFrame
    local relicsFound = 0
    
    local relicsFolder = workspace:FindFirstChild('Folder')
    if not relicsFolder then
        print('Folder not found!')
        return
    end
    
    print('Scanning for relics inside Folder...')
    for _, relic in ipairs(relicsFolder:GetChildren()) do
        if relic:IsA('Model') then
            local relicPart = relic:FindFirstChildWhichIsA('Part')
            local proximityPrompt = relic:FindFirstChildWhichIsA('ProximityPrompt', true)
            
            if relicPart and proximityPrompt then
                relicsFound = relicsFound + 1
                print('Found Relic:', relic.Name)
                tweenToPosition(relicPart)
                interactWithPrompt(proximityPrompt)
                humanoidRootPart.CFrame = originalPosition
            end
        end
    end
    
    if relicsFound == 0 then
        print('No Ancient Relics found.')
    else
        print('Processed', relicsFound, 'relic(s).')
    end
end

local function toggleAutoPickupRelic(enabled)
    autoPickupRelicEnabled = enabled
    
    if autoPickupRelicEnabled then
        print('Auto Pickup Ancient Relic enabled')
        while autoPickupRelicEnabled do
            pcall(scanForRelics)
            wait(1)
        end
    else
        print('Auto Pickup Ancient Relic disabled')
    end
end

autoPickupRelicSwitch.event:Connect(toggleAutoPickupRelic)

local autoPickupPotionSwitch = autoTab.new('switch', {
    text = 'Auto Pickup Potion',
    tooltip = 'Automatically picks up potions by teleporting to them and interacting with them.'
})
autoPickupPotionSwitch.set(false)

local autoPickupPotionEnabled = false

local function tweenToPotion(potion)
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild('HumanoidRootPart')
    local originalPosition = humanoidRootPart.CFrame
    
    if potion and potion:IsA('Part') then
        print('Tweening to potion:', potion.Name)
        local targetPosition = potion.CFrame + Vector3.new(0, 3, 0)
        local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
        
        local tween = tweenService:Create(humanoidRootPart, tweenInfo, {
            CFrame = targetPosition
        })
        tween:Play()
        tween.Completed:Wait()
        
        local humanoid = character:FindFirstChild('Humanoid')
        if humanoid then
            humanoid.Jump = true
            wait(1)
        end
        
        local returnTween = tweenService:Create(humanoidRootPart, tweenInfo, {
            CFrame = originalPosition
        })
        returnTween:Play()
    end
end

local function scanForPotions()
    local potionsFound = 0
    local potionsFolder = workspace:FindFirstChild('Folder')
    
    if not potionsFolder then
        print('Folder not found!')
        return
    end
    
    for _, potion in ipairs(potionsFolder:GetChildren()) do
        if potion:IsA('Part') then
            potionsFound = potionsFound + 1
            print('Found Potion:', potion.Name)
            tweenToPotion(potion)
        end
    end
    
    if potionsFound == 0 then
        print('No potions found.')
    else
        print('Processed', potionsFound, 'potion(s).')
    end
end

local function toggleAutoPickupPotion(enabled)
    autoPickupPotionEnabled = enabled
    
    if autoPickupPotionEnabled then
        print('Auto Pickup Potion enabled')
        while autoPickupPotionEnabled do
            pcall(scanForPotions)
            wait(1)
        end
    else
        print('Auto Pickup Potion disabled')
    end
end

autoPickupPotionSwitch.event:Connect(toggleAutoPickupPotion)

autoTab.new('label', {
    text = '------------------',
    color = Color3.new(1, 1, 1)
})

local autoUseCoinBoostSwitch = autoTab.new('switch', {
    text = 'Auto Use Potion: Coin Boost',
    tooltip = 'Automatically uses Coin Boost potion every 2 seconds.'
})
autoUseCoinBoostSwitch.set(false)

local autoUseCoinBoostEnabled = false

local function toggleAutoUseCoinBoost(enabled)
    autoUseCoinBoostEnabled = enabled
    
    if autoUseCoinBoostEnabled then
        print('Auto Use Potion: Coin Boost enabled')
        while autoUseCoinBoostEnabled do
            pcall(function()
                local args = {
                    [1] = 104010
                }
                game:GetService('ReplicatedStorage'):WaitForChild('Remotes'):WaitForChild('Item'):WaitForChild('Use'):FireServer(unpack(args))
            end)
            wait(2)
        end
    else
        print('Auto Use Potion: Coin Boost disabled')
    end
end

autoUseCoinBoostSwitch.event:Connect(toggleAutoUseCoinBoost)

local autoUseLuckSwitch = autoTab.new('switch', {
    text = 'Auto Use Potion: Luck',
    tooltip = 'Automatically uses Luck potion every 2 seconds.'
})
autoUseLuckSwitch.set(false)

local autoUseLuckEnabled = false

local function toggleAutoUseLuck(enabled)
    autoUseLuckEnabled = enabled
    
    if autoUseLuckEnabled then
        print('Auto Use Potion: Luck enabled')
        while autoUseLuckEnabled do
            pcall(function()
                local args = {
                    [1] = 104001
                }
                game:GetService('ReplicatedStorage'):WaitForChild('Remotes'):WaitForChild('Item'):WaitForChild('Use'):FireServer(unpack(args))
            end)
            wait(2)
        end
    else
        print('Auto Use Potion: Luck disabled')
    end
end

autoUseLuckSwitch.event:Connect(toggleAutoUseLuck)

local autoUseRollSpeedSwitch = autoTab.new('switch', {
    text = 'Auto Use Potion: Roll Speed',
    tooltip = 'Automatically uses Roll Speed potion every 2 seconds.'
})
autoUseRollSpeedSwitch.set(false)

local autoUseRollSpeedEnabled = false

local function toggleAutoUseRollSpeed(enabled)
    autoUseRollSpeedEnabled = enabled
    
    if autoUseRollSpeedEnabled then
        print('Auto Use Potion: Roll Speed enabled')
        while autoUseRollSpeedEnabled do
            pcall(function()
                local args = {
                    [1] = 104004
                }
                game:GetService('ReplicatedStorage'):WaitForChild('Remotes'):WaitForChild('Item'):WaitForChild('Use'):FireServer(unpack(args))
            end)
            wait(2)
        end
    else
        print('Auto Use Potion: Roll Speed disabled')
    end
end

autoUseRollSpeedSwitch.event:Connect(toggleAutoUseRollSpeed)

local autoUseExpSwitch = autoTab.new('switch', {
    text = 'Auto Use Potion: Exp',
    tooltip = 'Automatically uses Exp potion every 2 seconds.'
})
autoUseExpSwitch.set(false)

local autoUseExpEnabled = false

local function toggleAutoUseExp(enabled)
    autoUseExpEnabled = enabled
    
    if autoUseExpEnabled then
        print('Auto Use Potion: Exp enabled')
        while autoUseExpEnabled do
            pcall(function()
                local args = {
                    [1] = 104007
                }
                game:GetService('ReplicatedStorage'):WaitForChild('Remotes'):WaitForChild('Item'):WaitForChild('Use'):FireServer(unpack(args))
            end)
            wait(2)
        end
    else
        print('Auto Use Potion: Exp disabled')
    end
end

autoUseExpSwitch.event:Connect(toggleAutoUseExp)

local miscTab = mainWindow.new({
    text = 'Misc',
    padding = Vector2.new(10, 10)
})

local autoRollEnabled = false

local function toggleAutoRoll(enabled)
    autoRollEnabled = enabled
    
    if autoRollEnabled then
        print('Auto Roll enabled')
        while autoRollEnabled do
            pcall(function()
                game:GetService('ReplicatedStorage'):WaitForChild('Remotes'):WaitForChild('RollChest'):WaitForChild('RollCmd'):FireServer()
            end)
            wait(0.01)
        end
    else
        print('Auto Roll disabled')
    end
end

local autoRollSwitch = miscTab.new('switch', {
    text = 'Auto Roll',
    tooltip = 'Rolls chests automatically every 0.01 seconds.'
})
autoRollSwitch.set(false)
autoRollSwitch.event:Connect(toggleAutoRoll)

local equipBestEnabled = false

local function toggleEquipBest(enabled)
    equipBestEnabled = enabled
    
    if equipBestEnabled then
        print('Equip Best enabled')
        while equipBestEnabled do
            pcall(function()
                game:GetService('ReplicatedStorage'):WaitForChild('Remotes'):WaitForChild('Backpack'):WaitForChild('EquipBest'):FireServer()
            end)
            wait(1)
        end
    else
        print('Equip Best disabled')
    end
end

local autoRebirthEnabled = false

local function toggleAutoRebirth(enabled)
    autoRebirthEnabled = enabled
    
    if autoRebirthEnabled then
        print('Auto Rebirth enabled')
        while autoRebirthEnabled do
            pcall(function()
                game:GetService('ReplicatedStorage'):WaitForChild('Remotes'):WaitForChild('Rebirth'):WaitForChild('TryRebirth'):FireServer()
            end)
            wait(5)
        end
    else
        print('Auto Rebirth disabled')
    end
end

local autoRebirthSwitch = miscTab.new('switch', {
    text = 'Auto Rebirth',
    tooltip = 'Automatically attempts to rebirth every 5 seconds.'
})
autoRebirthSwitch.set(false)
autoRebirthSwitch.event:Connect(toggleAutoRebirth)

local equipBestSwitch = miscTab.new('switch', {
    text = 'Equip Best',
    tooltip = 'Automatically equips the best items every second.'
})
equipBestSwitch.set(false)
equipBestSwitch.event:Connect(toggleEquipBest)

local autoSellEnabled = false

local function sellItems()
    local deleteRemote = game:GetService('ReplicatedStorage'):WaitForChild('Remotes'):WaitForChild('Backpack'):WaitForChild('Delete')
    local itemsToSell = {}
    
    for i = 1, 30 do
        table.insert(itemsToSell, i)
    end
    
    if #itemsToSell > 0 then
        local args = {
            itemsToSell,
            nil,
            true
        }
        deleteRemote:FireServer(unpack(args))
        print('Auto Sell triggered for items:', table.concat(itemsToSell, ', '))
    else
        print('No items to sell.')
    end
end

local function toggleAutoSell(enabled)
    autoSellEnabled = enabled
    
    if autoSellEnabled then
        print('Auto Sell enabled')
        while autoSellEnabled do
            sellItems()
            wait(5)
        end
    else
        print('Auto Sell disabled')
    end
end

local autoSellSwitch = miscTab.new('switch', {
    text = 'Auto Sell',
    tooltip = 'Automatically sells all inventory items every second.'
})
autoSellSwitch.set(false)
autoSellSwitch.event:Connect(toggleAutoSell)

local virtualInput = game:GetService("VirtualInputManager")
local autoSkillEnabled = false

local function toggleAutoSkill(enabled)
    autoSkillEnabled = enabled
    if autoSkillEnabled then
        print("Auto Skills habilitado")
        spawn(function()
            while autoSkillEnabled do
                for _, key in ipairs({Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three}) do
                    virtualInput:SendKeyEvent(true, key, false, game)
                    wait(0.1)
                    virtualInput:SendKeyEvent(false, key, false, game)
                    wait(0.2)
                end
                wait(5)
            end
        end)
    else
        print("Auto Skills deshabilitado")
    end
end

local autoSkillSwitch = miscTab.new('switch', {
    text = 'Auto Skills',
    tooltip = 'Activa automáticamente habilidades 1, 2 y 3 del alma.'
})
autoSkillSwitch.set(false)
autoSkillSwitch.event:Connect(toggleAutoSkill)


miscTab.new('label', {
    text = 'Note: Use Equip Best, Auto Roll, and Auto Sell for faster progression.',
    color = Color3.new(0, 1, 0)
})

local teleportTab = mainWindow.new({
    text = 'TP',
    padding = Vector2.new(10, 10)
})

local function teleportTo(position)
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:FindFirstChild('HumanoidRootPart')
    
    if humanoidRootPart then
        humanoidRootPart.CFrame = CFrame.new(position)
        print('Teleported to:', position)
    else
        print('HumanoidRootPart not found!')
    end
end

local island1Button = teleportTab.new('button', {
    text = 'Teleport to Island 1'
})
island1Button.event:Connect(function()
    teleportTo(Vector3.new(-1.07, 97.28999999999996, -400.77))
end)

local island2Button = teleportTab.new('button', {
    text = 'Teleport to Island 2'
})
island2Button.event:Connect(function()
    teleportTo(Vector3.new(-667.32, 72.21, 1327.43))
end)

local island3Button = teleportTab.new('button', {
    text = 'Teleport to Island 3'
})
island3Button.event:Connect(function()
    teleportTo(Vector3.new(1731.0500000000002, 53.58, 2833.26))
end)

local infoTab = mainWindow.new({
    text = 'Info',
    padding = Vector2.new(10, 10)
})

infoTab.new('label', {
    text = 'Contact',
    color = Color3.new(1, 1, 1)
})

infoTab.new('label', {
    text = "Contact\n------------\nDiscord: Pancakq\nDiscord Server: https://discord.gg/J37PW97j6a",
    color = Color3.new(1, 1, 1)
})

infoTab.new('label', {
    text = " "
})

infoTab.new('label', {
    text = 'Please have your DMs turned on for non-friends as I do not want to flood my own friend list.',
    color = Color3.new(1, 0, 0)
})

local function toggleEventFarm(enabled)
    eventFarmEnabled = enabled
    if not enabled then return end

    spawn(function()
        local player = game.Players.LocalPlayer

        -- Coordenadas configurables
        local PLATFORMS = {
            Vector3.new(-392.63, 54.05, -742.08),
            Vector3.new(-450.12, 54.05, -800.15),
            Vector3.new(-500.25, 54.05, -720.35),
            -- Agrega más plataformas si es necesario
        }

        local BOSS_RESPAWNS = {
            Vector3.new(-400.41, 52.54, -809.72),
            Vector3.new(-396.26, 53.31, -869.96),
            Vector3.new(-380.10, 53.20, -830.42),
            -- Agrega más posiciones de respawn
        }

        local ENTER_THRESHOLD = 100
        local EXIT_THRESHOLD = 150
        local AT_PLATFORM_THRESHOLD = 10

        -- Función para teletransportarse
        local function teleportTo(position)
            local character = player.Character or player.CharacterAdded:Wait()
            local hrp = character:WaitForChild("HumanoidRootPart")
            hrp.CFrame = CFrame.new(position)
        end

        local function refreshCharacter()
            local character = player.Character or player.CharacterAdded:Wait()
            local humanoid = character:WaitForChild("Humanoid")
            local hrp = character:WaitForChild("HumanoidRootPart")
            return character, humanoid, hrp
        end

        local step = 0
        local cycleStart = nil
        local platformIndex = 1

        while eventFarmEnabled do
            local character, humanoid, hrp = refreshCharacter()

            -- Ir a la plataforma actual
            local currentPlatform = PLATFORMS[platformIndex]
            teleportTo(currentPlatform)
            wait(3)

            if (hrp.Position - currentPlatform).Magnitude > AT_PLATFORM_THRESHOLD then
                warn("[Event Farm] No se pudo posicionar en la plataforma " .. platformIndex)
                platformIndex = (platformIndex % #PLATFORMS) + 1 -- Saltar a la siguiente plataforma
                continue
            end

            print("[Event Farm] Iniciando ciclo en plataforma #" .. platformIndex)

            step = 0
            cycleStart = tick()

            while eventFarmEnabled do
                local pos = hrp.Position

                if step == 0 then
                    -- Espera a que el jugador entre a la dungeon (alejarse de la plataforma)
                    if (pos - currentPlatform).Magnitude > ENTER_THRESHOLD then
                        print("[Event Farm] Entraste a la dungeon.")
                        step = 1
                    end
                elseif step == 1 then
                    -- Espera a que reaparezca cerca de un respawn
                    for _, respawnPos in pairs(BOSS_RESPAWNS) do
                        if (pos - respawnPos).Magnitude < EXIT_THRESHOLD then
                            print("[Event Farm] Dungeon finalizada. Regresando a la plataforma...")
                            character, humanoid, hrp = refreshCharacter()
                            teleportTo(currentPlatform)
                            wait(3)

                            if (hrp.Position - currentPlatform).Magnitude <= AT_PLATFORM_THRESHOLD then
                                local duration = tick() - cycleStart
                                print("⏱️ Duración del ciclo: " .. string.format("%.2f", duration) .. " segundos.")
                                step = 0
                                cycleStart = nil
                                break
                            end
                        end
                    end
                end

                wait(1)
            end

            -- Cambiar a la siguiente plataforma para el próximo ciclo
            platformIndex = (platformIndex % #PLATFORMS) + 1
        end
    end)
end

eventTab.new('switch', {
    text = 'Auto Dungeon',
    tooltip = 'Ingresa automaticamente a la dungeon'
}).event:Connect(toggleEventFarm)
