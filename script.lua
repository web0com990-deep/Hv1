--==================================================
-- THEPTHAI SCP SIMULATOR V.1
-- Roblox Studio | LocalScript
-- UI เดิม + ปุ่ม OPEN แบบสี่เหลี่ยมขอบมน
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- CONFIG
local CONFIG = {
    FlyHeight = 20,
    MoveSpeed = 80,
    StopDistance = 2,
    PauseDuration = 2,
    DescendSpeed = 50,
}

local Theme = {
    Background = Color3.fromRGB(15, 17, 23),
    Sidebar = Color3.fromRGB(21, 24, 32),
    Card = Color3.fromRGB(28, 32, 42),
    Accent = Color3.fromRGB(105, 145, 255),
    Text = Color3.fromRGB(240, 243, 250),
    Muted = Color3.fromRGB(145, 153, 172),
    Border = Color3.fromRGB(47, 53, 68),
    Green = Color3.fromRGB(100, 220, 160),
    Red = Color3.fromRGB(255, 120, 130),
}

-- WORLD
local mainFolder = Workspace:WaitForChild("Main", 15)
if not mainFolder then
    warn("[Thepthai SCP Simulator] ไม่พบ Workspace.Main")
    return
end

local dropsFolder = mainFolder:WaitForChild("Drops", 15)
if not dropsFolder then
    warn("[Thepthai SCP Simulator] ไม่พบ Workspace.Main.Drops")
    return
end

-- STATE
local selectedFolder
local selectedNPCName
local currentTarget
local autoMove = false
local noclip = false
local targetPause = false
local moveConnection
local noclipConnection
local characterConnection
local originalCollisions = {}
local collisionConnections = {}
local statusText = "Ready"
local currentPage = "Overview"
local connections = {}

local function keepConnection(connection)
    table.insert(connections, connection)
    return connection
end

-- CHARACTER HELPERS
local function getCharacter()
    return player.Character
end

local function getRoot(character)
    character = character or getCharacter()
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(character)
    character = character or getCharacter()
    return character and character:FindFirstChildOfClass("Humanoid")
end

-- NPC HELPERS
local function isValidNPC(model)
    if not model or not model:IsA("Model") then return false end
    if not model:IsDescendantOf(dropsFolder) then return false end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")
    return humanoid ~= nil and humanoid.Health > 0 and root ~= nil
end

local function getNPCNames(folder)
    local names, seen = {}, {}
    if not folder or not folder.Parent then return names end

    for _, object in ipairs(folder:GetDescendants()) do
        if object:IsA("Model") and isValidNPC(object) and not seen[object.Name] then
            seen[object.Name] = true
            table.insert(names, object.Name)
        end
    end
    table.sort(names)
    return names
end

local function getTargets()
    local targets = {}
    if not selectedFolder or not selectedFolder.Parent
        or not selectedFolder:IsDescendantOf(dropsFolder) then
        return targets
    end

    for _, object in ipairs(selectedFolder:GetDescendants()) do
        if object:IsA("Model") and isValidNPC(object)
            and (selectedNPCName == nil or object.Name == selectedNPCName) then
            table.insert(targets, object)
        end
    end
    return targets
end

local function getTarget()
    local root = getRoot()
    local targets = getTargets()
    if #targets == 0 then return nil end
    if not root then return targets[1] end

    local closest, closestDistance
    closestDistance = math.huge
    for _, target in ipairs(targets) do
        local targetRoot = target:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            local distance = (targetRoot.Position - root.Position).Magnitude
            if distance < closestDistance then
                closestDistance = distance
                closest = target
            end
        end
    end
    return closest
end

-- REMOVE OLD UI
local oldGui = playerGui:FindFirstChild("ThepthaiSCP_v1")
if oldGui then oldGui:Destroy() end

-- UI HELPERS
local function addCorner(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 9)
    corner.Parent = object
    return corner
end

local function addStroke(object, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Theme.Border
    stroke.Thickness = thickness or 1
    stroke.Parent = object
    return stroke
end

local function makeLabel(parent, text, size, position, fontSize, color)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = size
    label.Position = position
    label.Text = text
    label.TextColor3 = color or Theme.Text
    label.TextSize = fontSize or 13
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextWrapped = true
    label.Parent = parent
    return label
end

local function makeButton(parent, text, size, position, accent)
    local button = Instance.new("TextButton")
    button.Size = size
    button.Position = position
    button.BackgroundColor3 = accent and Theme.Accent or Theme.Card
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Theme.Text
    button.TextSize = 12
    button.Font = Enum.Font.GothamMedium
    button.AutoButtonColor = true
    button.Parent = parent
    addCorner(button, 8)
    return button
end

local function makeCard(parent, height)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -4, 0, height)
    card.BackgroundColor3 = Theme.Card
    card.BorderSizePixel = 0
    card.Parent = parent
    addCorner(card, 10)
    addStroke(card, Theme.Border, 1)
    return card
end

-- SCREEN GUI
local gui = Instance.new("ScreenGui")
gui.Name = "ThepthaiSCP_v1"
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- MAIN WINDOW
local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.Size = UDim2.fromOffset(560, 390)
panel.Position = UDim2.new(0.5, -280, 0.5, -195)
panel.BackgroundColor3 = Theme.Background
panel.BorderSizePixel = 0
panel.Active = true
panel.ClipsDescendants = true
panel.Parent = gui
addCorner(panel, 14)
addStroke(panel, Theme.Border, 1)

local uiScale = Instance.new("UIScale")
uiScale.Parent = panel

local function updateScale()
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    uiScale.Scale = math.min(1, viewport.X / 580, viewport.Y / 410)
end

local function connectCamera(camera)
    if not camera then return end
    keepConnection(camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))
    updateScale()
end

updateScale()
connectCamera(Workspace.CurrentCamera)
keepConnection(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    connectCamera(Workspace.CurrentCamera)
end))

-- SIDEBAR
local sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.Size = UDim2.new(0, 145, 1, 0)
sidebar.BackgroundColor3 = Theme.Sidebar
sidebar.BorderSizePixel = 0
sidebar.Parent = panel

makeLabel(sidebar, "THEPTHAI", UDim2.new(1, -24, 0, 27), UDim2.fromOffset(16, 14), 17, Theme.Accent)
makeLabel(sidebar, "SCP SIMULATOR V.1", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(16, 39), 8, Theme.Muted)

local sidebarDivider = Instance.new("Frame")
sidebarDivider.Size = UDim2.new(1, -28, 0, 1)
sidebarDivider.Position = UDim2.fromOffset(14, 69)
sidebarDivider.BackgroundColor3 = Theme.Border
sidebarDivider.BorderSizePixel = 0
sidebarDivider.Parent = sidebar

makeLabel(sidebar, "WORKSPACE", UDim2.new(1, -24, 0, 20), UDim2.fromOffset(16, 80), 9, Theme.Muted)

local navContainer = Instance.new("Frame")
navContainer.Name = "Navigation"
navContainer.Position = UDim2.fromOffset(9, 106)
navContainer.Size = UDim2.new(1, -18, 0, 175)
navContainer.BackgroundTransparency = 1
navContainer.Parent = sidebar

local navLayout = Instance.new("UIListLayout")
navLayout.Padding = UDim.new(0, 7)
navLayout.SortOrder = Enum.SortOrder.LayoutOrder
navLayout.Parent = navContainer

-- HEADER
local header = Instance.new("Frame")
header.Name = "Header"
header.Position = UDim2.fromOffset(145, 0)
header.Size = UDim2.new(1, -145, 0, 58)
header.BackgroundTransparency = 1
header.Active = true
header.Parent = panel

local pageTitle = makeLabel(header, "Overview", UDim2.new(1, -100, 1, 0), UDim2.fromOffset(20, 0), 18)
local closeButton = makeButton(header, "×", UDim2.fromOffset(30, 30), UDim2.new(1, -43, 0, 14))
closeButton.TextSize = 21

-- PAGE HOST
local pageHost = Instance.new("Frame")
pageHost.Name = "PageHost"
pageHost.Position = UDim2.fromOffset(160, 64)
pageHost.Size = UDim2.new(1, -175, 1, -78)
pageHost.BackgroundTransparency = 1
pageHost.ClipsDescendants = true
pageHost.Parent = panel

local pages, navButtons = {}, {}

local function createPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Theme.Accent
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new()
    page.Visible = false
    page.Parent = pageHost

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    pages[name] = page
    return page
end

local pageDefinitions = {
    {id = "Overview", text = "⌂   Overview"},
    {id = "Monsters", text = "◎   Monsters"},
    {id = "Movement", text = "↗   Movement"},
    {id = "Settings", text = "⚙   Settings"},
}

for i, info in ipairs(pageDefinitions) do
    local button = makeButton(navContainer, info.text, UDim2.new(1, 0, 0, 36), UDim2.new(), false)
    button.LayoutOrder = i
    button.TextXAlignment = Enum.TextXAlignment.Left
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 10)
    padding.Parent = button
    navButtons[info.id] = button
end

local overview = createPage("Overview")
local monstersPage = createPage("Monsters")
local movementPage = createPage("Movement")
local settingsPage = createPage("Settings")

local function showPage(name)
    currentPage = name
    for pageName, page in pairs(pages) do
        page.Visible = pageName == name
    end
    for pageName, button in pairs(navButtons) do
        button.BackgroundColor3 = pageName == name and Theme.Accent or Theme.Sidebar
    end
    pageTitle.Text = name
end

for _, info in ipairs(pageDefinitions) do
    navButtons[info.id].Activated:Connect(function()
        showPage(info.id)
    end)
end

-- OVERVIEW PAGE
local welcomeCard = makeCard(overview, 80)
makeLabel(welcomeCard, "CONTROL CENTER", UDim2.new(1, -24, 0, 20), UDim2.fromOffset(12, 8), 10, Theme.Muted)
makeLabel(welcomeCard, "Your battle, your control.", UDim2.new(1, -24, 0, 27), UDim2.fromOffset(12, 32), 15)

local statusCard = makeCard(overview, 68)
makeLabel(statusCard, "SYSTEM STATUS", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 5), 10, Theme.Muted)
local statusLabel = makeLabel(statusCard, "●  Ready", UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 28), 13, Theme.Green)

local targetCard = makeCard(overview, 64)
makeLabel(targetCard, "CURRENT TARGET", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 5), 10, Theme.Muted)
local targetLabel = makeLabel(targetCard, "No target", UDim2.new(1, -24, 0, 27), UDim2.fromOffset(12, 27), 13)
local quickButton = makeButton(overview, "▶   Start Flight", UDim2.new(1, -4, 0, 38), UDim2.new(), true)

-- MONSTERS PAGE
local folderCard = makeCard(monstersPage, 77)
makeLabel(folderCard, "TARGET FOLDER", UDim2.new(1, -24, 0, 20), UDim2.fromOffset(12, 5), 10, Theme.Muted)
local folderButton = makeButton(folderCard, "Choose folder  ›", UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 34))
folderButton.TextXAlignment = Enum.TextXAlignment.Left
local folderPad = Instance.new("UIPadding")
folderPad.PaddingLeft = UDim.new(0, 10)
folderPad.Parent = folderButton

local npcCard = makeCard(monstersPage, 77)
makeLabel(npcCard, "NPC FILTER", UDim2.new(1, -24, 0, 20), UDim2.fromOffset(12, 5), 10, Theme.Muted)
local npcButton = makeButton(npcCard, "All NPCs  ›", UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 34))
npcButton.TextXAlignment = Enum.TextXAlignment.Left
local npcPad = Instance.new("UIPadding")
npcPad.PaddingLeft = UDim.new(0, 10)
npcPad.Parent = npcButton

local refreshButton = makeButton(monstersPage, "↻   Refresh list", UDim2.new(1, -4, 0, 34), UDim2.new())
local listCard = makeCard(monstersPage, 175)
makeLabel(listCard, "AVAILABLE ITEMS", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 4), 10, Theme.Muted)

local list = Instance.new("ScrollingFrame")
list.Name = "Items"
list.Position = UDim2.fromOffset(10, 32)
list.Size = UDim2.new(1, -20, 1, -40)
list.BackgroundColor3 = Theme.Background
list.BorderSizePixel = 0
list.ScrollBarThickness = 3
list.ScrollBarImageColor3 = Theme.Accent
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = listCard
addCorner(list, 7)

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 5)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 5)
listPadding.PaddingLeft = UDim.new(0, 5)
listPadding.PaddingRight = UDim.new(0, 5)
listPadding.PaddingBottom = UDim.new(0, 5)
listPadding.Parent = list

-- MOVEMENT PAGE
local flightCard = makeCard(movementPage, 86)
makeLabel(flightCard, "OVERHEAD FLIGHT", UDim2.new(1, -24, 0, 20), UDim2.fromOffset(12, 5), 10, Theme.Muted)
local moveButton = makeButton(flightCard, "Flight: OFF", UDim2.new(1, -24, 0, 36), UDim2.fromOffset(12, 36))

local heightCard = makeCard(movementPage, 74)
makeLabel(heightCard, "FLIGHT HEIGHT", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 4), 10, Theme.Muted)
local heightValue = makeLabel(heightCard, tostring(CONFIG.FlyHeight) .. " studs", UDim2.new(0, 105, 0, 28), UDim2.fromOffset(12, 28), 13)
local heightDown = makeButton(heightCard, "−", UDim2.fromOffset(40, 29), UDim2.new(1, -92, 0, 28))
local heightUp = makeButton(heightCard, "+", UDim2.fromOffset(40, 29), UDim2.new(1, -46, 0, 28))

local speedCard = makeCard(movementPage, 74)
makeLabel(speedCard, "MOVEMENT SPEED", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 4), 10, Theme.Muted)
local speedValue = makeLabel(speedCard, tostring(CONFIG.MoveSpeed), UDim2.new(0, 105, 0, 28), UDim2.fromOffset(12, 28), 13)
local speedDown = makeButton(speedCard, "−", UDim2.fromOffset(40, 29), UDim2.new(1, -92, 0, 28))
local speedUp = makeButton(speedCard, "+", UDim2.fromOffset(40, 29), UDim2.new(1, -46, 0, 28))

-- SETTINGS PAGE
local collisionCard = makeCard(settingsPage, 83)
makeLabel(collisionCard, "COLLISION", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 5), 10, Theme.Muted)
local noclipButton = makeButton(collisionCard, "Noclip: OFF", UDim2.new(1, -24, 0, 35), UDim2.fromOffset(12, 34))

local pauseCard = makeCard(settingsPage, 74)
makeLabel(pauseCard, "TARGET CHANGE PAUSE", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 4), 10, Theme.Muted)
local pauseValue = makeLabel(pauseCard, tostring(CONFIG.PauseDuration) .. " seconds", UDim2.new(0, 130, 0, 28), UDim2.fromOffset(12, 28), 12)
local pauseDown = makeButton(pauseCard, "−", UDim2.fromOffset(40, 29), UDim2.new(1, -92, 0, 28))
local pauseUp = makeButton(pauseCard, "+", UDim2.fromOffset(40, 29), UDim2.new(1, -46, 0, 28))
local resetButton = makeButton(settingsPage, "Reset movement settings", UDim2.new(1, -4, 0, 35), UDim2.new())

-- LIST FUNCTIONS
local function clearList()
    for _, item in ipairs(list:GetChildren()) do
        if item:IsA("TextButton") or item:IsA("TextLabel") then
            item:Destroy()
        end
    end
end

local function addListItem(text, callback, order)
    local button = makeButton(list, text, UDim2.new(1, -4, 0, 30), UDim2.new())
    button.LayoutOrder = order or 1
    button.TextXAlignment = Enum.TextXAlignment.Left
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 9)
    padding.Parent = button
    button.Activated:Connect(callback)
    return button
end

local function refreshFolders()
    clearList()
    local folders = {}

    for _, object in ipairs(dropsFolder:GetChildren()) do
        if object:IsA("Folder") then
            table.insert(folders, object)
        end
    end

    table.sort(folders, function(a, b)
        local na, nb = tonumber(a.Name), tonumber(b.Name)
        if na and nb then return na < nb end
        if na then return true end
        if nb then return false end
        return a.Name < b.Name
    end)

    for i, folder in ipairs(folders) do
        addListItem("▸   " .. folder.Name, function()
            selectedFolder = folder
            selectedNPCName = nil
            currentTarget = nil
            folderButton.Text = "Folder: " .. folder.Name .. "  ›"
            npcButton.Text = "All NPCs  ›"
            statusText = "Selected folder: " .. folder.Name
            refreshFolders()
        end, i)
    end

    if #folders == 0 then
        addListItem("No folders found", function() end, 1)
    end
    list.CanvasPosition = Vector2.zero
end

local function refreshNPCs()
    clearList()
    if not selectedFolder or not selectedFolder.Parent
        or not selectedFolder:IsDescendantOf(dropsFolder) then
        addListItem("Choose a folder first", function() end, 1)
        return
    end

    addListItem("All NPCs", function()
        selectedNPCName = nil
        currentTarget = nil
        npcButton.Text = "All NPCs  ›"
        refreshNPCs()
    end, 1)

    local names = getNPCNames(selectedFolder)
    for i, name in ipairs(names) do
        addListItem(name, function()
            selectedNPCName = name
            currentTarget = nil
            npcButton.Text = name .. "  ›"
            refreshNPCs()
        end, i + 1)
    end
    if #names == 0 then
        addListItem("No living NPCs found", function() end, 2)
    end
end

folderButton.Activated:Connect(function()
    showPage("Monsters")
    refreshFolders()
end)

npcButton.Activated:Connect(function()
    showPage("Monsters")
    refreshNPCs()
end)

refreshButton.Activated:Connect(function()
    if selectedFolder and selectedFolder.Parent then
        refreshNPCs()
    else
        refreshFolders()
    end
end)

-- UI STATUS
local function syncUI()
    moveButton.Text = autoMove and "Flight: ON" or "Flight: OFF"
    quickButton.Text = autoMove and "■   Stop Flight" or "▶   Start Flight"
    noclipButton.Text = noclip and "Noclip: ON" or "Noclip: OFF"
    statusLabel.Text = "●  " .. statusText
    statusLabel.TextColor3 = autoMove and Theme.Green or Theme.Muted
    targetLabel.Text = currentTarget and currentTarget.Parent and currentTarget.Name or "No target"
end

-- FLIGHT SYSTEM
local function stopMove()
    autoMove = false
    targetPause = false
    if moveConnection then
        moveConnection:Disconnect()
        moveConnection = nil
    end
    local root = getRoot()
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    statusText = "Ready"
    syncUI()
end

local function startMove()
    stopMove()
    autoMove = true
    targetPause = false
    local pauseUntil = 0
    local descending = false
    local descendPosition

    statusText = "Starting flight"
    syncUI()

    moveConnection = RunService.Heartbeat:Connect(function(dt)
        if not autoMove then return end
        local character = getCharacter()
        local root = getRoot(character)
        local humanoid = getHumanoid(character)

        if not root or not humanoid or humanoid.Health <= 0 then
            statusText = "Waiting for character"
            syncUI()
            return
        end

        if currentTarget and not isValidNPC(currentTarget) then
            currentTarget = nil
            targetPause = true
            pauseUntil = os.clock() + CONFIG.PauseDuration
            descending = true
            descendPosition = root.Position - Vector3.new(0, CONFIG.FlyHeight, 0)
            statusText = "Target ended: descending"
            syncUI()
        end

        if targetPause then
            if descending and descendPosition then
                local offset = descendPosition - root.Position
                local distance = offset.Magnitude
                if distance > 0.15 then
                    local step = math.min(CONFIG.DescendSpeed * dt, distance)
                    root.CFrame = CFrame.new(root.Position + offset.Unit * step)
                else
                    root.CFrame = CFrame.new(descendPosition)
                    descending = false
                end
            end

            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            if os.clock() < pauseUntil then return end

            targetPause = false
            descending = false
            descendPosition = nil
            statusText = "Finding next target"
            syncUI()
        end

        if not currentTarget then currentTarget = getTarget() end
        if not currentTarget then
            statusText = "No NPC found"
            syncUI()
            return
        end

        local targetRoot = currentTarget:FindFirstChild("HumanoidRootPart")
        if not targetRoot or not isValidNPC(currentTarget) then
            currentTarget = nil
            return
        end

        local destination = targetRoot.Position + Vector3.new(0, CONFIG.FlyHeight, 0)
        local offset = destination - root.Position
        local distance = offset.Magnitude

        if distance > CONFIG.StopDistance then
            local step = math.min(CONFIG.MoveSpeed * dt, distance)
            local newPosition = root.Position + offset.Unit * step
            root.CFrame = CFrame.lookAt(newPosition, Vector3.new(targetRoot.Position.X, newPosition.Y, targetRoot.Position.Z))
        else
            root.CFrame = CFrame.lookAt(destination, targetRoot.Position)
        end

        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        statusText = "Flying above: " .. currentTarget.Name
        syncUI()
    end)
end

-- MOVEMENT CONTROLS
moveButton.Activated:Connect(function()
    if autoMove then stopMove() else startMove() end
end)

quickButton.Activated:Connect(function()
    if autoMove then stopMove() else startMove() end
end)

heightDown.Activated:Connect(function()
    CONFIG.FlyHeight = math.max(5, CONFIG.FlyHeight - 5)
    heightValue.Text = CONFIG.FlyHeight .. " studs"
end)

heightUp.Activated:Connect(function()
    CONFIG.FlyHeight = math.min(100, CONFIG.FlyHeight + 5)
    heightValue.Text = CONFIG.FlyHeight .. " studs"
end)

speedDown.Activated:Connect(function()
    CONFIG.MoveSpeed = math.max(10, CONFIG.MoveSpeed - 10)
    speedValue.Text = tostring(CONFIG.MoveSpeed)
end)

speedUp.Activated:Connect(function()
    CONFIG.MoveSpeed = math.min(200, CONFIG.MoveSpeed + 10)
    speedValue.Text = tostring(CONFIG.MoveSpeed)
end)

pauseDown.Activated:Connect(function()
    CONFIG.PauseDuration = math.max(0, math.floor((CONFIG.PauseDuration - 0.2) * 10 + 0.5) / 10)
    pauseValue.Text = string.format("%.1f seconds", CONFIG.PauseDuration)
end)

pauseUp.Activated:Connect(function()
    CONFIG.PauseDuration = math.min(10, math.floor((CONFIG.PauseDuration + 0.2) * 10 + 0.5) / 10)
    pauseValue.Text = string.format("%.1f seconds", CONFIG.PauseDuration)
end)

resetButton.Activated:Connect(function()
    CONFIG.FlyHeight = 20
    CONFIG.MoveSpeed = 80
    CONFIG.PauseDuration = 2
    heightValue.Text = CONFIG.FlyHeight .. " studs"
    speedValue.Text = tostring(CONFIG.MoveSpeed)
    pauseValue.Text = string.format("%.1f seconds", CONFIG.PauseDuration)
end)

-- NOCLIP
local function restoreCollisions()
    for part, oldValue in pairs(originalCollisions) do
        if part and part.Parent then
            part.CanCollide = oldValue
        end
    end
    table.clear(originalCollisions)
end

local function stopNoclip()
    noclip = false
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    for _, connection in ipairs(collisionConnections) do
        connection:Disconnect()
    end
    table.clear(collisionConnections)
    restoreCollisions()
    syncUI()
end

local function startNoclip()
    stopNoclip()
    noclip = true

    local function disableCharacterCollision(character)
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if originalCollisions[part] == nil then
                    originalCollisions[part] = part.CanCollide
                end
                part.CanCollide = false
            end
        end
    end

    local character = getCharacter()
    if character then
        disableCharacterCollision(character)
        table.insert(collisionConnections, character.DescendantAdded:Connect(function(part)
            if noclip and part:IsA("BasePart") then
                if originalCollisions[part] == nil then
                    originalCollisions[part] = part.CanCollide
                end
                part.CanCollide = false
            end
        end))
    end

    noclipConnection = RunService.Stepped:Connect(function()
        if not noclip then return end
        local currentCharacter = getCharacter()
        if currentCharacter then disableCharacterCollision(currentCharacter) end
    end)
    syncUI()
end

noclipButton.Activated:Connect(function()
    if noclip then stopNoclip() else startNoclip() end
end)

-- DRAG WINDOW
local dragging = false
local dragInput
local dragStart
local startPosition

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragInput = input
        dragStart = input.Position
        startPosition = panel.Position
    end
end)

keepConnection(UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(
            startPosition.X.Scale, startPosition.X.Offset + delta.X,
            startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
        )
    end
end))

keepConnection(UserInputService.InputEnded:Connect(function(input)
    if input == dragInput then
        dragging = false
        dragInput = nil
    end
end))

-- MINIMIZE / RESTORE
local toggleButton = makeButton(
    gui,
    "OPEN",
    UDim2.fromOffset(54, 54),
    UDim2.new(0, 14, 0.5, -27),
    true
)
toggleButton.Name = "OpenUI"
toggleButton.Visible = false
toggleButton.Active = true
toggleButton.Selectable = true
toggleButton.AutoButtonColor = true
toggleButton.TextSize = 11
toggleButton.ZIndex = 100
addStroke(toggleButton, Theme.Border, 1)

-- ปุ่ม OPEN ไม่ใช้ Draggable เพราะอาจแย่งการคลิกบนมือถือ
local function setPanelVisible(visible)
    panel.Visible = visible
    toggleButton.Visible = not visible

    if visible then
        panel.ZIndex = 1
        panel.Position = UDim2.new(0.5, -280, 0.5, -195)
    else
        toggleButton.ZIndex = 100
    end
end

closeButton.Activated:Connect(function()
    setPanelVisible(false)
end)

toggleButton.Activated:Connect(function()
    setPanelVisible(true)
end)

-- รองรับการคลิกเมาส์เพิ่มเติม เผื่ออุปกรณ์ที่ Activated ทำงานไม่ครบ
toggleButton.MouseButton1Click:Connect(function()
    if not panel.Visible then
        setPanelVisible(true)
    end
end)

-- RESPAWN / CLEANUP
characterConnection = player.CharacterAdded:Connect(function()
    currentTarget = nil
    table.clear(originalCollisions)

    if autoMove then
        task.defer(function()
            if autoMove then startMove() end
        end)
    end

    if noclip then
        task.defer(function()
            if noclip then startNoclip() end
        end)
    end
end)

gui.Destroying:Connect(function()
    stopMove()
    stopNoclip()
    if characterConnection then
        characterConnection:Disconnect()
        characterConnection = nil
    end
    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
    table.clear(connections)
end)

-- INITIALIZE
showPage("Overview")
refreshFolders()
syncUI()

print("[Thepthai SCP Simulator v.1] UI loaded successfully")
