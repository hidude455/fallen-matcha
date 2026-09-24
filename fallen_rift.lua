-- FALLEN / RIFT | Matcha external Lua VM
-- Fallen Survival: root place 10228136016, universe 3747388906
-- Right Shift: show/hide menu  |  End: unload  |  Right mouse: hold aim assist

local ROOT_PLACE_ID = 10228136016
local UNIVERSE_ID = 3747388906
local SERVER_PLACES = {
    [13800717766] = true, -- Large Server
    [15479377118] = true, -- Small Server
    [16849012343] = true  -- Medium Server
}
local VERSION = "0.6"
local currentPlaceId = tonumber(game.PlaceId) or 0
local function readUniverseId()
    local ok, id = pcall(function() return tonumber(game.GameId) or 0 end)
    return ok and id or 0
end
local currentUniverseId = readUniverseId()
if currentPlaceId ~= ROOT_PLACE_ID and not SERVER_PLACES[currentPlaceId] and currentUniverseId == 0 then
    local deadline = tick() + 5
    while currentUniverseId == 0 and tick() < deadline do
        wait(0.2)
        currentUniverseId = readUniverseId()
    end
end
if currentPlaceId ~= ROOT_PLACE_ID and not SERVER_PLACES[currentPlaceId] and currentUniverseId ~= UNIVERSE_ID then
    notify("Fallen not detected. Place " .. tostring(currentPlaceId) .. ", game " .. tostring(currentUniverseId), "FALLEN / RIFT", 7)
    return
end

if _G.FallenRift and _G.FallenRift.running then
    _G.FallenRift.running = false
    wait(0.1)
end

local controller = { running = true }
_G.FallenRift = controller

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do wait(0.1); LocalPlayer = Players.LocalPlayer end
while not Workspace.CurrentCamera do wait(0.1) end
local Mouse = LocalPlayer:GetMouse()
local V2 = Vector2.new
local V3 = Vector3.new
local RGB = Color3.fromRGB

local theme = {
    bg = RGB(16, 18, 29), panel = RGB(25, 27, 39), raised = RGB(37, 40, 56),
    hover = RGB(48, 51, 70), line = RGB(65, 66, 85),
    text = RGB(246, 245, 251), muted = RGB(182, 183, 203),
    violet = RGB(141, 87, 250), cyan = RGB(112, 209, 231), green = RGB(135, 214, 163),
    coral = RGB(244, 135, 148), white = RGB(255, 255, 255)
}
local accents = { theme.violet, theme.cyan, theme.green, theme.coral }
local accentNames = { "VIOLET", "CYAN", "MINT", "CORAL" }
local cfg = {
    menu = true, tab = 1, accent = 1,
    esp = true, boxes = true, names = true, distances = true, health = true,
    snaplines = false, teammates = false, maxDistance = 450,
    aim = false, aimFov = 150, smooth = 8, showFov = true,
    world = true, nodes = true, barrels = true, plants = true, crates = true,
    glowSelected = true, itemOutlines = false, worldRange = 300, worldPage = 1,
    crosshair = false, crosshairSize = 7,
    noclip = false, spider = false, climbSpeed = 18,
    cameraFov = 70, zoom = false, zoomFov = 35, cameraPage = 1,
    thirdPerson = false, thirdDistance = 8, freecam = false, freecamSpeed = 2,
    screenTint = false, tintStrength = 12,
    triggerClick = false, fastClick = false, hitRange = 25, hitInterval = 180
}

local allDrawings = {}
local pools = { Square = {}, Text = {}, Line = {}, Circle = {} }
local used = { Square = 0, Text = 0, Line = 0, Circle = 0 }
local espDrawings = {}
local uiScale, uiOriginX, uiOriginY = 1, 0, 0
local function newDraw(kind)
    local o = Drawing.new(kind)
    o.Visible = false
    allDrawings[#allDrawings + 1] = o
    return o
end
local function pooled(kind)
    used[kind] = used[kind] + 1
    local i = used[kind]
    if not pools[kind][i] then pools[kind][i] = newDraw(kind) end
    return pools[kind][i]
end
local function pixel(n) return math.floor(n + 0.5) end
local function rect(x, y, w, h, color, corner)
    local o = pooled("Square")
    o.Position, o.Size, o.Color = V2(pixel(uiOriginX + x * uiScale), pixel(uiOriginY + y * uiScale)), V2(pixel(w * uiScale), pixel(h * uiScale)), color
    o.Filled, o.Transparency, o.Visible = true, 1, true
    pcall(function() o.Corner = pixel((corner or 0) * uiScale) end)
    pcall(function() o.ZIndex = 10 end)
    return o
end
local function styleText(o, size, bold, centered, outlined)
    local fontOk, font = pcall(function()
        return bold and Drawing.Fonts.SystemBold or Drawing.Fonts.System
    end)
    if fontOk and font then pcall(function() o.Font = font end) end
    local textSizeOk = pcall(function() o.Size = size or 13 end)
    if not textSizeOk then pcall(function() o.FontSize = size or 13 end) end
    pcall(function() o.Outline = outlined or false end)
    pcall(function() o.Center = centered or false end)
    pcall(function() o.ZIndex = 30 end)
end
local function label(x, y, value, color, size, bold)
    local o = pooled("Text")
    o.Position, o.Text, o.Color = V2(pixel(uiOriginX + x * uiScale), pixel(uiOriginY + y * uiScale)), value, color
    styleText(o, math.max(12, pixel((size or 13) * uiScale)), bold, false, false)
    o.Transparency, o.Visible = 1, true
    return o
end
local function line(x1, y1, x2, y2, color, thickness)
    local o = pooled("Line")
    o.From, o.To, o.Color, o.Thickness = V2(pixel(uiOriginX + x1 * uiScale), pixel(uiOriginY + y1 * uiScale)), V2(pixel(uiOriginX + x2 * uiScale), pixel(uiOriginY + y2 * uiScale)), color, math.max(1, pixel((thickness or 1) * uiScale))
    o.Transparency, o.Visible = 1, true
    pcall(function() o.ZIndex = 20 end)
    return o
end
local function hideUnused()
    for kind, list in pairs(pools) do
        for i = used[kind] + 1, #list do list[i].Visible = false end
    end
end
local function pointIn(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end
local function clamp(n, a, b) return math.max(a, math.min(b, n)) end
local function round(n) return n >= 0 and math.floor(n + 0.5) or math.ceil(n - 0.5) end
local activeSlider = nil
local function menuRow(x, y, w, title, hint, on, mx, my, click)
    local hot = pointIn(mx, my, x, y, w, 53)
    rect(x, y, w, 53, hot and theme.hover or theme.raised, 10)
    label(x + 15, y + 6, title, theme.text, 14, true)
    label(x + 15, y + 28, hint, theme.muted, 11)
    rect(x + w - 59, y + 14, 43, 25, on and accents[cfg.accent] or theme.line, 12)
    rect(x + w - (on and 39 or 56), y + 18, 17, 17, theme.white, 9)
    return click and hot
end
local function choiceRow(x, y, w, title, hint, value, mx, my, click)
    local hot = pointIn(mx, my, x, y, w, 53)
    rect(x, y, w, 53, hot and theme.hover or theme.raised, 10)
    label(x + 15, y + 6, title, theme.text, 14, true)
    label(x + 15, y + 28, hint, theme.muted, 11)
    rect(x + w - 102, y + 12, 86, 29, theme.line, 7)
    label(x + w - 93, y + 19, value, accents[cfg.accent], 11, true)
    return click and hot
end
local function sliderRow(x, y, w, title, hint, value, minValue, maxValue, mx, my, held)
    local hot = pointIn(mx, my, x, y, w, 66)
    if not held then activeSlider = nil end
    if held and (activeSlider == title or (not activeSlider and pointIn(mx, my, x + 5, y + 39, w - 10, 27))) then
        activeSlider = title
        value = round(clamp(minValue + (mx - x - 16) / (w - 32) * (maxValue - minValue), minValue, maxValue))
    end
    rect(x, y, w, 66, hot and theme.hover or theme.raised, 10)
    label(x + 15, y + 6, title, theme.text, 14, true)
    label(x + 15, y + 28, hint, theme.muted, 11)
    label(x + w - 52, y + 6, tostring(value), accents[cfg.accent], 13, true)
    rect(x + 16, y + 50, w - 32, 5, theme.line, 3)
    local fill = (w - 32) * (value - minValue) / (maxValue - minValue)
    rect(x + 16, y + 50, fill, 5, accents[cfg.accent], 3)
    rect(x + 10 + fill, y + 45, 15, 15, theme.white, 8)
    return value
end

local menuPosition = { x = nil, y = nil, dragging = false, offsetX = 0, offsetY = 0 }
local function drawMenu(mx, my, click, held)
    if not cfg.menu then menuPosition.dragging = false; activeSlider = nil; hideUnused(); return end
    local viewport = Workspace.CurrentCamera.ViewportSize
    uiScale = math.min(1.2, (viewport.X - 24) / 590, (viewport.Y - 24) / 440)
    uiScale = math.max(0.1, uiScale)
    local menuW, menuH = 590 * uiScale, 440 * uiScale
    if menuPosition.x == nil then
        menuPosition.x = math.floor((viewport.X - menuW) / 2)
        menuPosition.y = math.floor((viewport.Y - menuH) / 2)
    end
    local maxX, maxY = math.max(0, viewport.X - menuW), math.max(0, viewport.Y - menuH)
    menuPosition.x = clamp(menuPosition.x, 0, maxX)
    menuPosition.y = clamp(menuPosition.y, 0, maxY)
    local x, y = menuPosition.x, menuPosition.y
    if not held then menuPosition.dragging = false; activeSlider = nil end
    local function menuHit(hx, hy, hw, hh)
        return pointIn(mx, my, x + hx * uiScale, y + hy * uiScale, hw * uiScale, hh * uiScale)
    end
    if click and menuHit(550, 12, 30, 29) then
        cfg.menu = false
        menuPosition.dragging = false
        hideUnused()
        return
    end
    if click and (menuHit(0, 0, 139, 86) or menuHit(140, 0, 410, 12)) then
        menuPosition.dragging = true
        menuPosition.offsetX, menuPosition.offsetY = mx - x, my - y
    end
    if menuPosition.dragging and held then
        x = clamp(mx - menuPosition.offsetX, 0, maxX)
        y = clamp(my - menuPosition.offsetY, 0, maxY)
        menuPosition.x, menuPosition.y = x, y
    end
    uiOriginX, uiOriginY = x, y
    mx, my = (mx - x) / uiScale, (my - y) / uiScale
    x, y = 0, 0
    local shadow = rect(x + 5, y + 6, 590, 440, theme.bg, 14)
    shadow.Transparency = 0.55
    rect(x, y, 590, 440, theme.line, 14)
    rect(x + 1, y + 1, 588, 438, theme.panel, 13)
    rect(x + 1, y + 1, 34, 438, theme.bg, 13)
    rect(x + 22, y + 1, 117, 438, theme.bg, 0)
    label(x + 19, y + 22, "FALLEN", theme.text, 19, true)
    label(x + 20, y + 49, "R I F T", accents[cfg.accent], 10, true)
    label(x + 20, y + 70, "DRAG TO MOVE", theme.muted, 9)
    line(x + 139, y + 1, x + 139, y + 439, theme.line)
    local tabNames = { "OVERVIEW", "AIMBOT", "VISUALS", "WORLD", "COMBAT", "CAMERA", "MISC" }
    for i = 1, 7 do
        local ty = y + 91 + (i - 1) * 41
        if i == cfg.tab then rect(x + 8, ty, 123, 36, accents[cfg.accent], 8)
        elseif pointIn(mx, my, x + 8, ty, 123, 36) then rect(x + 8, ty, 123, 36, theme.hover, 8) end
        label(x + 22, ty + 10, tabNames[i], i == cfg.tab and theme.white or theme.muted, 12, i == cfg.tab)
        if click and pointIn(mx, my, x + 8, ty, 123, 36) then cfg.tab = i end
    end
    label(x + 20, y + 382, "ALT+CLICK SELECT", theme.muted, 9)
    label(x + 20, y + 400, "RSHIFT  HIDE", theme.muted, 9)
    label(x + 20, y + 416, "END     UNLOAD", theme.muted, 9)

    local topNames = { "Home", "Aim", "ESP", "Loot", "Fight", "Camera", "Misc" }
    for i = 1, 7 do
        local tx = x + 145 + (i - 1) * 58
        if i == cfg.tab then rect(tx, y + 13, 54, 27, accents[cfg.accent], 13)
        elseif pointIn(mx, my, tx, y + 13, 54, 27) then rect(tx, y + 13, 54, 27, theme.hover, 13) end
        label(tx + 5, y + 19, topNames[i], i == cfg.tab and theme.white or theme.muted, 10, i == cfg.tab)
        if click and pointIn(mx, my, tx, y + 13, 54, 27) then cfg.tab = i end
    end
    rect(x + 550, y + 13, 30, 27, theme.raised, 8)
    label(x + 560, y + 19, "X", theme.coral, 11, true)
    line(x + 140, y + 51, x + 589, y + 51, theme.line)
    local bx, by, bw = x + 161, y + 61, 405
    label(bx, by, tabNames[cfg.tab], theme.text, 18, true)
    label(bx, by + 26, "Fallen Survival / external control", theme.muted, 10)
    line(bx, by + 52, bx + bw, by + 52, theme.line)
    local rowY = by + 68
    if cfg.tab == 1 then
        rect(bx, rowY, bw, 71, theme.raised, 10)
        label(bx + 14, rowY + 11, "FALLEN SURVIVAL", theme.text, 15, true)
        label(bx + 14, rowY + 37, "Player visuals + on-hold aim assist", theme.muted, 11)
        rect(bx + bw - 86, rowY + 17, 70, 19, theme.line, 9)
        label(bx + bw - 76, rowY + 20, "LOCAL VM", accents[cfg.accent], 9)
        rowY = rowY + 83
        if menuRow(bx, rowY, bw, "Player ESP", "Boxes, names, distance and health", cfg.esp, mx, my, click) then cfg.esp = not cfg.esp end
        rowY = rowY + 63
        if menuRow(bx, rowY, bw, "Aim assist", "Hold right mouse near a target", cfg.aim, mx, my, click) then cfg.aim = not cfg.aim end
        rowY = rowY + 75
        label(bx, rowY, "STATUS", accents[cfg.accent], 10, true)
        label(bx, rowY + 20, "Game data: Matcha player wrappers", theme.muted, 11)
        label(bx, rowY + 39, "Overlay: Drawing API / no game UI objects", theme.muted, 11)
    elseif cfg.tab == 2 then
        if menuRow(bx, rowY, bw, "Aim assist", "Hold right mouse to engage", cfg.aim, mx, my, click) then cfg.aim = not cfg.aim end
        rowY = rowY + 63
        if menuRow(bx, rowY, bw, "Show FOV", "Display target selection radius", cfg.showFov, mx, my, click) then cfg.showFov = not cfg.showFov end
        rowY = rowY + 63
        cfg.aimFov = sliderRow(bx, rowY, bw, "FOV radius", "Screen pixels around crosshair", cfg.aimFov, 40, 350, mx, my, held)
        rowY = rowY + 76
        cfg.smooth = sliderRow(bx, rowY, bw, "Smoothing", "Higher is slower", cfg.smooth, 2, 20, mx, my, held)
        rowY = rowY + 77
        label(bx, rowY, "Visible on-screen targets only", theme.muted, 10)
    elseif cfg.tab == 3 then
        if menuRow(bx, rowY, bw, "Player ESP", "Master visual toggle", cfg.esp, mx, my, click) then cfg.esp = not cfg.esp end
        rowY = rowY + 57
        if menuRow(bx, rowY, bw, "Boxes", "Outline player silhouettes", cfg.boxes, mx, my, click) then cfg.boxes = not cfg.boxes end
        rowY = rowY + 57
        if menuRow(bx, rowY, bw, "Names + distance", "Identify and range targets", cfg.names, mx, my, click) then cfg.names = not cfg.names; cfg.distances = cfg.names end
        rowY = rowY + 57
        if menuRow(bx, rowY, bw, "Health bars", "Show available health value", cfg.health, mx, my, click) then cfg.health = not cfg.health end
        rowY = rowY + 57
        if menuRow(bx, rowY, bw, "Snaplines", "Lines from the lower screen edge", cfg.snaplines, mx, my, click) then cfg.snaplines = not cfg.snaplines end
    elseif cfg.tab == 4 then
        local pageX = bx + bw - 112
        rect(pageX, by + 25, 52, 23, cfg.worldPage == 1 and accents[cfg.accent] or theme.raised, 5)
        rect(pageX + 56, by + 25, 52, 23, cfg.worldPage == 2 and accents[cfg.accent] or theme.raised, 5)
        label(pageX + 12, by + 30, "ESP", theme.white, 10, true)
        label(pageX + 64, by + 30, "EXTRA", theme.white, 10, true)
        if click and pointIn(mx, my, pageX, by + 25, 52, 23) then cfg.worldPage = 1 end
        if click and pointIn(mx, my, pageX + 56, by + 25, 52, 23) then cfg.worldPage = 2 end
        if cfg.worldPage == 1 then
            if menuRow(bx, rowY, bw, "World ESP", "Master resource overlay", cfg.world, mx, my, click) then cfg.world = not cfg.world end
            rowY = rowY + 57
            if menuRow(bx, rowY, bw, "Nodes", "Ore, stone, sulfur and wood", cfg.nodes, mx, my, click) then cfg.nodes = not cfg.nodes end
            rowY = rowY + 57
            if menuRow(bx, rowY, bw, "Barrels + crates", "Loot containers", cfg.barrels and cfg.crates, mx, my, click) then cfg.barrels = not cfg.barrels; cfg.crates = cfg.barrels end
            rowY = rowY + 57
            if menuRow(bx, rowY, bw, "Plants", "Hemp, berries and crops", cfg.plants, mx, my, click) then cfg.plants = not cfg.plants end
            rowY = rowY + 57
            if menuRow(bx, rowY, bw, "Selected glow", "Alt + click a marker to focus it", cfg.glowSelected, mx, my, click) then cfg.glowSelected = not cfg.glowSelected end
        else
            if menuRow(bx, rowY, bw, "Item outlines", "Screen-space outlines around resources", cfg.itemOutlines, mx, my, click) then cfg.itemOutlines = not cfg.itemOutlines end
            rowY = rowY + 57
            if menuRow(bx, rowY, bw, "Crosshair", "Center reticle drawn by Matcha", cfg.crosshair, mx, my, click) then cfg.crosshair = not cfg.crosshair end
            rowY = rowY + 64
            cfg.crosshairSize = sliderRow(bx, rowY, bw, "Crosshair size", "Reticle arm length in pixels", cfg.crosshairSize, 3, 20, mx, my, held)
            rowY = rowY + 76
            cfg.worldRange = sliderRow(bx, rowY, bw, "World range", "Maximum resource distance", cfg.worldRange, 50, 600, mx, my, held)
        end
    elseif cfg.tab == 5 then
        if menuRow(bx, rowY, bw, "Target click", "Right mouse + target near crosshair", cfg.triggerClick, mx, my, click) then cfg.triggerClick = not cfg.triggerClick end
        rowY = rowY + 57
        if menuRow(bx, rowY, bw, "Fast click", "Hold V to repeat left click", cfg.fastClick, mx, my, click) then cfg.fastClick = not cfg.fastClick end
        rowY = rowY + 64
        cfg.hitRange = sliderRow(bx, rowY, bw, "Target range", "Maximum target distance", cfg.hitRange, 5, 60, mx, my, held)
        rowY = rowY + 76
        cfg.hitInterval = sliderRow(bx, rowY, bw, "Click interval", "Milliseconds between clicks", cfg.hitInterval, 90, 500, mx, my, held)
        rowY = rowY + 76
        label(bx, rowY, "Requires an equipped tool and game acceptance", theme.muted, 10)
    elseif cfg.tab == 6 then
        local pageX = bx + bw - 112
        rect(pageX, by + 25, 52, 23, cfg.cameraPage == 1 and accents[cfg.accent] or theme.raised, 5)
        rect(pageX + 56, by + 25, 52, 23, cfg.cameraPage == 2 and accents[cfg.accent] or theme.raised, 5)
        label(pageX + 10, by + 30, "VIEW", theme.white, 10, true)
        label(pageX + 64, by + 30, "MODES", theme.white, 10, true)
        if click and pointIn(mx, my, pageX, by + 25, 52, 23) then cfg.cameraPage = 1 end
        if click and pointIn(mx, my, pageX + 56, by + 25, 52, 23) then cfg.cameraPage = 2 end
        if cfg.cameraPage == 1 then
            cfg.cameraFov = sliderRow(bx, rowY, bw, "Camera FOV", "Base field of view", cfg.cameraFov, 55, 110, mx, my, held)
            rowY = rowY + 76
            if menuRow(bx, rowY, bw, "Hold zoom", "Hold Z while menu is closed", cfg.zoom, mx, my, click) then cfg.zoom = not cfg.zoom end
            rowY = rowY + 64
            cfg.zoomFov = sliderRow(bx, rowY, bw, "Zoom FOV", "Field of view while holding Z", cfg.zoomFov, 15, 65, mx, my, held)
            rowY = rowY + 76
            if menuRow(bx, rowY, bw, "Screen tint", "Transparent accent-color overlay", cfg.screenTint, mx, my, click) then cfg.screenTint = not cfg.screenTint end
        else
            if menuRow(bx, rowY, bw, "Third person (beta)", "Camera pulled behind your character", cfg.thirdPerson, mx, my, click) then
                cfg.thirdPerson = not cfg.thirdPerson
                if cfg.thirdPerson then cfg.freecam = false end
            end
            rowY = rowY + 64
            cfg.thirdDistance = sliderRow(bx, rowY, bw, "View distance", "Camera distance behind character", cfg.thirdDistance, 4, 18, mx, my, held)
            rowY = rowY + 76
            if menuRow(bx, rowY, bw, "Freecam (beta)", "WASD / Q E / arrow keys", cfg.freecam, mx, my, click) then
                cfg.freecam = not cfg.freecam
                if cfg.freecam then cfg.thirdPerson = false end
            end
            rowY = rowY + 64
            cfg.freecamSpeed = sliderRow(bx, rowY, bw, "Freecam speed", "Units per frame; Left Shift boosts", cfg.freecamSpeed, 1, 8, mx, my, held)
        end
    else
        if menuRow(bx, rowY, bw, "Show teammates", "Include same-team players", cfg.teammates, mx, my, click) then cfg.teammates = not cfg.teammates end
        rowY = rowY + 57
        if menuRow(bx, rowY, bw, "Noclip", "Local character collision", cfg.noclip, mx, my, click) then cfg.noclip = not cfg.noclip end
        rowY = rowY + 57
        if menuRow(bx, rowY, bw, "Spider climb", "Hold W into a wall to rise", cfg.spider, mx, my, click) then cfg.spider = not cfg.spider end
        rowY = rowY + 58
        if choiceRow(bx, rowY, bw, "Accent color", "Menu, reticle and screen tint", accentNames[cfg.accent], mx, my, click) then cfg.accent = cfg.accent % #accents + 1 end
        rowY = rowY + 64
        cfg.tintStrength = sliderRow(bx, rowY, bw, "Tint strength", "Overlay opacity percent", cfg.tintStrength, 3, 25, mx, my, held)
    end
    hideUnused()
end

local function newEspEntry()
    local e = { lines = {}, name = newDraw("Text"), hpBack = newDraw("Square"), hpFill = newDraw("Square"), snap = newDraw("Line") }
    for i = 1, 4 do e.lines[i] = newDraw("Line") end
    styleText(e.name, 12, false, true, true)
    return e
end
local function hideEsp(e)
    for i = 1, 4 do e.lines[i].Visible = false end
    e.name.Visible, e.hpBack.Visible, e.hpFill.Visible, e.snap.Visible = false, false, false, false
end
local function getTarget(player, localRoot)
    if player == LocalPlayer then return nil end
    if not cfg.teammates and LocalPlayer.Team and player.Team == LocalPlayer.Team then return nil end
    local char = player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
    if not root then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return nil end
    local distance = (root.Position - localRoot.Position).Magnitude
    if distance > cfg.maxDistance then return nil end
    local head = char:FindFirstChild("Head")
    local headPos = head and head.Position or root.Position + V3(0, 2, 0)
    local top, topVisible = WorldToScreen(headPos + V3(0, 0.5, 0))
    local bottom, bottomVisible = WorldToScreen(root.Position - V3(0, 3, 0))
    if not topVisible or not bottomVisible then return nil end
    return { player = player, root = root, hum = hum, distance = distance, top = top, bottom = bottom, aim = top }
end
local function drawEsp(e, t, viewport)
    local h = clamp(t.bottom.Y - t.top.Y, 12, 500)
    local w = h * 0.54
    local cx = (t.top.X + t.bottom.X) / 2
    local x, y = cx - w / 2, t.top.Y
    local color = accents[cfg.accent]
    local segments = { {x,y,x+w,y}, {x+w,y,x+w,y+h}, {x+w,y+h,x,y+h}, {x,y+h,x,y} }
    for i = 1, 4 do
        local d, s = e.lines[i], segments[i]
        d.From, d.To, d.Color, d.Thickness, d.Visible = V2(s[1],s[2]), V2(s[3],s[4]), color, 1, cfg.boxes
    end
    e.name.Text = (cfg.names and t.player.Name or "") .. (cfg.distances and ("  [" .. tostring(round(t.distance)) .. "m]") or "")
    e.name.Position, e.name.Color, e.name.Visible = V2(cx, y - 20), theme.white, cfg.names or cfg.distances
    local hp = t.hum and clamp(t.hum.Health / math.max(t.hum.MaxHealth, 1), 0, 1) or 1
    e.hpBack.Position, e.hpBack.Size, e.hpBack.Color = V2(x, y + h + 4), V2(w, 3), theme.line
    e.hpFill.Position, e.hpFill.Size, e.hpFill.Color = V2(x, y + h + 4), V2(w * hp, 3), theme.green
    e.hpBack.Filled, e.hpFill.Filled, e.hpBack.Visible, e.hpFill.Visible = true, true, cfg.health, cfg.health
    e.snap.From, e.snap.To, e.snap.Color, e.snap.Thickness = V2(viewport.X/2, viewport.Y-2), V2(cx, y+h), color, 1
    e.snap.Visible = cfg.snaplines
end

local worldCandidates, worldDrawings, glowLines = {}, {}, {}
local selectedWorld = nil
local nextWorldScan = 0
local collisionOriginals = {}
local nextCollisionUpdate = 0
local initialFov = Workspace.CurrentCamera.FieldOfView
cfg.cameraFov = round(initialFov)

local function classify(name)
    local n = string.lower(name)
    if string.find(n, "barrel", 1, true) then return "barrels" end
    if string.find(n, "crate", 1, true) or string.find(n, "chest", 1, true) or string.find(n, "lootbox", 1, true) then return "crates" end
    if string.find(n, "plant", 1, true) or string.find(n, "hemp", 1, true) or string.find(n, "berry", 1, true) or string.find(n, "corn", 1, true) or string.find(n, "tomato", 1, true) or string.find(n, "potato", 1, true) or string.find(n, "pumpkin", 1, true) or string.find(n, "mushroom", 1, true) or string.find(n, "cactus", 1, true) then return "plants" end
    if string.find(n, "ore", 1, true) or string.find(n, "node", 1, true) or string.find(n, "sulfur", 1, true) or string.find(n, "stone", 1, true) or string.find(n, "metal", 1, true) or string.find(n, "iron", 1, true) or string.find(n, "tree", 1, true) or string.find(n, "wood", 1, true) then return "nodes" end
    return nil
end
local function firstPart(obj)
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        if obj.PrimaryPart then return obj.PrimaryPart end
        for _, child in ipairs(obj:GetDescendants()) do
            if child:IsA("BasePart") then return child end
        end
    end
    return nil
end
local function scanWorld(myRoot)
    local fresh, seen = {}, {}
    local buckets = { nodes = {}, barrels = {}, plants = {}, crates = {} }
    local characters = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then characters[#characters + 1] = player.Character end
    end
    local descendants = Workspace:GetDescendants()
    for i = 1, math.min(#descendants, 15000) do
        local obj = descendants[i]
        local kind = classify(obj.Name)
        if kind and (obj:IsA("Model") or obj:IsA("BasePart")) then
            local part = firstPart(obj)
            if part then
                local key = part.Address or tostring(part)
                if not seen[key] then
                    seen[key] = true
                    local carried = false
                    for _, char in ipairs(characters) do
                        if obj:IsDescendantOf(char) then carried = true; break end
                    end
                    if not carried then
                        local distance = (part.Position - myRoot.Position).Magnitude
                        if distance <= cfg.worldRange + 100 then
                            buckets[kind][#buckets[kind] + 1] = { object = obj, part = part, kind = kind, name = obj.Name, distance = distance }
                        end
                    end
                end
            end
        end
    end
    for _, bucket in pairs(buckets) do
        table.sort(bucket, function(a, b) return a.distance < b.distance end)
        for i = 1, math.min(#bucket, 75) do fresh[#fresh + 1] = bucket[i] end
    end
    worldCandidates = fresh
end
local function newWorldDrawing()
    local e = { ring = newDraw("Circle"), text = newDraw("Text"), outline = {} }
    e.ring.Radius, e.ring.NumSides, e.ring.Thickness = 5, 16, 2
    styleText(e.text, 11, false, true, true)
    for i = 1, 4 do e.outline[i] = newDraw("Line") end
    return e
end
local function hideWorld()
    for _, e in ipairs(worldDrawings) do
        e.ring.Visible, e.text.Visible = false, false
        for i = 1, 4 do e.outline[i].Visible = false end
    end
    for _, l in ipairs(glowLines) do l.Visible = false end
end
local function worldColor(kind)
    if kind == "nodes" then return theme.cyan end
    if kind == "barrels" then return theme.coral end
    if kind == "plants" then return theme.green end
    return accents[cfg.accent]
end
local function addPartPoints(part, points)
    local p, s = part.Position, part.Size
    local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
    local offsets = {
        V3(-hx,-hy,-hz), V3(-hx,-hy,hz), V3(-hx,hy,-hz), V3(-hx,hy,hz),
        V3(hx,-hy,-hz), V3(hx,-hy,hz), V3(hx,hy,-hz), V3(hx,hy,hz)
    }
    for _, offset in ipairs(offsets) do
        local point, visible = WorldToScreen(p + offset)
        if visible then points[#points + 1] = { x = point.X, y = point.Y } end
    end
end
local function hull(points)
    table.sort(points, function(a,b) return a.x == b.x and a.y < b.y or a.x < b.x end)
    local function cross(a,b,c) return (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x) end
    local lower = {}
    for _, p in ipairs(points) do
        while #lower >= 2 and cross(lower[#lower-1], lower[#lower], p) <= 0 do table.remove(lower) end
        lower[#lower+1] = p
    end
    local upper = {}
    for i = #points, 1, -1 do
        local p = points[i]
        while #upper >= 2 and cross(upper[#upper-1], upper[#upper], p) <= 0 do table.remove(upper) end
        upper[#upper+1] = p
    end
    table.remove(lower)
    table.remove(upper)
    for _, p in ipairs(upper) do lower[#lower+1] = p end
    return lower
end
local function drawSelectedGlow(entry)
    local points = {}
    if entry.object:IsA("Model") then
        local parts = entry.object:GetDescendants()
        local added = 0
        for _, part in ipairs(parts) do
            if part:IsA("BasePart") then
                addPartPoints(part, points)
                added = added + 1
                if added >= 16 then break end
            end
        end
    else
        addPartPoints(entry.part, points)
    end
    if #points < 3 then return end
    local outline = hull(points)
    local color = worldColor(entry.kind)
    for i = 1, math.min(#outline, 32) do
        local a, b = outline[i], outline[i % #outline + 1]
        for layer = 1, 2 do
            local index = (i - 1) * 2 + layer
            if not glowLines[index] then glowLines[index] = newDraw("Line") end
            local l = glowLines[index]
            l.From, l.To, l.Color = V2(a.x,a.y), V2(b.x,b.y), color
            l.Thickness, l.Transparency, l.Visible = layer == 1 and 8 or 2, layer == 1 and 0.35 or 1, true
        end
    end
end
local function renderWorld(myRoot, mx, my, altClick)
    hideWorld()
    if not cfg.world then return end
    local visibleList = {}
    for _, entry in ipairs(worldCandidates) do
        if cfg[entry.kind] then
            local ok, position, distance, screen, visible = pcall(function()
                local pos = entry.part.Position
                local range = (pos - myRoot.Position).Magnitude
                local projected, onScreen = WorldToScreen(pos)
                return pos, range, projected, onScreen
            end)
            if ok and visible and distance <= cfg.worldRange then
                visibleList[#visibleList + 1] = { entry = entry, screen = screen, distance = distance }
            end
        end
    end
    table.sort(visibleList, function(a, b) return a.distance < b.distance end)
    local closest, closestScore = nil, 38
    for i = 1, math.min(#visibleList, 45) do
        local item = visibleList[i]
        local entry, screen, distance = item.entry, item.screen, item.distance
        if not worldDrawings[i] then worldDrawings[i] = newWorldDrawing() end
        local e = worldDrawings[i]
        local color = worldColor(entry.kind)
        e.ring.Position, e.ring.Color, e.ring.Visible = screen, color, true
        e.text.Position, e.text.Color = V2(screen.X, screen.Y - 19), color
        e.text.Text = string.upper(entry.name) .. "  " .. tostring(round(distance)) .. "m"
        e.text.Visible = true
        if cfg.itemOutlines and i <= 24 then
            local points = {}
            addPartPoints(entry.part, points)
            if #points >= 2 then
                local minX, minY, maxX, maxY = points[1].x, points[1].y, points[1].x, points[1].y
                for _, point in ipairs(points) do
                    minX, minY = math.min(minX, point.x), math.min(minY, point.y)
                    maxX, maxY = math.max(maxX, point.x), math.max(maxY, point.y)
                end
                local sides = {
                    {minX, minY, maxX, minY}, {maxX, minY, maxX, maxY},
                    {maxX, maxY, minX, maxY}, {minX, maxY, minX, minY}
                }
                for side = 1, 4 do
                    local edge, coords = e.outline[side], sides[side]
                    edge.From, edge.To, edge.Color, edge.Thickness = V2(coords[1], coords[2]), V2(coords[3], coords[4]), color, 2
                    edge.Visible = true
                end
            end
        end
        if altClick then
            local dx, dy = screen.X - mx, screen.Y - my
            local score = math.sqrt(dx*dx + dy*dy)
            if score < closestScore then closest, closestScore = entry, score end
        end
        if cfg.glowSelected and selectedWorld == entry.object then drawSelectedGlow(entry) end
    end
    if altClick and closest then
        selectedWorld = closest.object
        notify("Focused " .. closest.name, "FALLEN / RIFT", 2)
    end
end
local function restoreCollisions()
    for part, original in pairs(collisionOriginals) do
        pcall(function() part.CanCollide = original end)
        collisionOriginals[part] = nil
    end
end
local warnedNoclip, warnedSpider = false, false
local function updateMovement(char, root, camera)
    if cfg.noclip then
        if tick() >= nextCollisionUpdate then
            nextCollisionUpdate = tick() + 0.1
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    if collisionOriginals[part] == nil then collisionOriginals[part] = part.CanCollide end
                    local ok = pcall(function() part.CanCollide = false end)
                    if not ok or part.CanCollide then
                        cfg.noclip = false
                        restoreCollisions()
                        if not warnedNoclip then notify("Noclip write unavailable in this Matcha build.", "FALLEN / RIFT", 4); warnedNoclip = true end
                        break
                    end
                end
            end
        end
    elseif next(collisionOriginals) then restoreCollisions() end
    if cfg.spider and isrbxactive() and iskeypressed(0x57) and not cfg.menu then
        local look = camera.CFrame.LookVector
        local horizontal = V3(look.X, 0, look.Z)
        if horizontal.Magnitude > 0.01 then
            local forward = horizontal.Unit
            local hit = Workspace:Raycast(root.Position + V3(0, 1, 0), forward * 3)
            if hit and hit.Instance and hit.Instance:IsDescendantOf(char) then
                hit = Workspace:Raycast(root.Position + V3(0, 1, 0) + forward * 1.4, forward * 2)
            end
            if hit and hit.Instance and not hit.Instance:IsDescendantOf(char) then
                local old = root.AssemblyLinearVelocity
                local ok = pcall(function() root.AssemblyLinearVelocity = V3(old.X, cfg.climbSpeed, old.Z) end)
                if not ok and not warnedSpider then
                    cfg.spider = false
                    notify("Spider climb velocity write unavailable.", "FALLEN / RIFT", 4)
                    warnedSpider = true
                end
            end
        end
    end
end

local cameraFrameBefore, freecamFrame = nil, nil
local warnedThirdPerson, warnedFreecam = false, false
local function lookAtFrame(position, target)
    local forward = (target - position).Unit
    local up = V3(0, 1, 0)
    local right = forward:Cross(up)
    if right.Magnitude < 0.01 then right = V3(1, 0, 0) end
    right = right.Unit
    up = right:Cross(forward).Unit
    return CFrame.new(position.X, position.Y, position.Z,
        right.X, up.X, -forward.X,
        right.Y, up.Y, -forward.Y,
        right.Z, up.Z, -forward.Z)
end
local function updateCameraMode(camera, root)
    if not cfg.thirdPerson and not cfg.freecam then
        if cameraFrameBefore then pcall(function() camera.CFrame = cameraFrameBefore end) end
        cameraFrameBefore, freecamFrame = nil, nil
        return
    end
    local mode = cfg.freecam and "freecam" or "third person"
    local ok, err = pcall(function()
        local current = camera.CFrame
        assert(current and current.LookVector, "Camera.CFrame unavailable")
        if not cameraFrameBefore then cameraFrameBefore = current end
        local nextFrame
        if cfg.thirdPerson then
            freecamFrame = nil
            local focus = root.Position + V3(0, 2, 0)
            local position = focus - current.LookVector * cfg.thirdDistance
            nextFrame = lookAtFrame(position, focus)
        else
            freecamFrame = freecamFrame or current
            local frame = freecamFrame
            if isrbxactive() and not cfg.menu then
                local yaw = (iskeypressed(0x27) and 1 or 0) - (iskeypressed(0x25) and 1 or 0)
                local pitch = (iskeypressed(0x28) and 1 or 0) - (iskeypressed(0x26) and 1 or 0)
                frame = frame * CFrame.Angles(pitch * 0.025, yaw * 0.025, 0)
                local speed = cfg.freecamSpeed * (iskeypressed(0xA0) and 3 or 1)
                local forward = (iskeypressed(0x57) and 1 or 0) - (iskeypressed(0x53) and 1 or 0)
                local sideways = (iskeypressed(0x44) and 1 or 0) - (iskeypressed(0x41) and 1 or 0)
                local vertical = (iskeypressed(0x45) and 1 or 0) - (iskeypressed(0x51) and 1 or 0)
                local position = frame.Position + frame.LookVector * (forward * speed)
                    + frame.RightVector * (sideways * speed) + V3(0, vertical * speed, 0)
                local rx, ry, rz = frame:ToOrientation()
                frame = CFrame.new(position.X, position.Y, position.Z) * CFrame.fromOrientation(rx, ry, rz)
            end
            nextFrame = frame
            freecamFrame = frame
        end
        camera.CFrame = nextFrame
        local applied = camera.CFrame
        assert((applied.Position - nextFrame.Position).Magnitude < 1, "Camera.CFrame write was ignored")
    end)
    if not ok then
        if cfg.thirdPerson then cfg.thirdPerson = false else cfg.freecam = false end
        if (mode == "third person" and not warnedThirdPerson) or (mode == "freecam" and not warnedFreecam) then
            notify(mode .. " unavailable in this Matcha build: " .. tostring(err), "FALLEN / RIFT", 5)
        end
        if mode == "third person" then warnedThirdPerson = true else warnedFreecam = true end
    end
end

local fovCircle = newDraw("Circle")
fovCircle.NumSides, fovCircle.Thickness = 64, 1
local tintOverlay = newDraw("Square")
local crosshairLines = {}
for i = 1, 4 do crosshairLines[i] = newDraw("Line") end
local nextHitTime = 0
local nextWarn = 0
local rightShiftWasDown, endWasDown, mouseWasDown = false, false, false
notify("RIFT v" .. VERSION .. " loaded. Right Shift: menu; End: unload.", "FALLEN / RIFT", 4)

while controller.running do
    local ok, err = pcall(function()
        local rightShiftDown = iskeypressed(0xA1)
        local endDown = iskeypressed(0x23)
        if rightShiftDown and not rightShiftWasDown then cfg.menu = not cfg.menu end
        if endDown and not endWasDown then controller.running = false end
        rightShiftWasDown, endWasDown = rightShiftDown, endDown
        if not controller.running then return end

        local mouseDown = ismouse1pressed()
        local clicked = mouseDown and not mouseWasDown
        mouseWasDown = mouseDown
        for kind in pairs(used) do used[kind] = 0 end
        drawMenu(Mouse.X, Mouse.Y, clicked, mouseDown)

        local camera = Workspace.CurrentCamera
        local viewport = camera.ViewportSize
        local centerX, centerY = viewport.X / 2, viewport.Y / 2
        tintOverlay.Position, tintOverlay.Size, tintOverlay.Color = V2(0, 0), viewport, accents[cfg.accent]
        tintOverlay.Filled, tintOverlay.Transparency, tintOverlay.Visible = true, cfg.tintStrength / 100, cfg.screenTint
        pcall(function() tintOverlay.ZIndex = -10 end)
        local gap, arm = 4, cfg.crosshairSize
        local crosshairSegments = {
            {centerX - gap - arm, centerY, centerX - gap, centerY},
            {centerX + gap, centerY, centerX + gap + arm, centerY},
            {centerX, centerY - gap - arm, centerX, centerY - gap},
            {centerX, centerY + gap, centerX, centerY + gap + arm}
        }
        for i = 1, 4 do
            local o, s = crosshairLines[i], crosshairSegments[i]
            o.From, o.To, o.Color, o.Thickness = V2(s[1], s[2]), V2(s[3], s[4]), accents[cfg.accent], 2
            o.Visible = cfg.crosshair
        end
        fovCircle.Position, fovCircle.Radius, fovCircle.Color = V2(centerX, centerY), cfg.aimFov, accents[cfg.accent]
        fovCircle.Visible = cfg.aim and cfg.showFov

        for _, e in ipairs(espDrawings) do hideEsp(e) end
        hideWorld()
        local myChar = LocalPlayer.Character
        local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar.PrimaryPart)
        local currentFov = cfg.zoom and iskeypressed(0x5A) and not cfg.menu and cfg.zoomFov or cfg.cameraFov
        pcall(function() camera.FieldOfView = currentFov end)
        if not myRoot then return end
        updateCameraMode(camera, myRoot)
        if cfg.world and tick() >= nextWorldScan then
            nextWorldScan = tick() + 2.5
            pcall(scanWorld, myRoot)
        end
        pcall(renderWorld, myRoot, Mouse.X, Mouse.Y, not cfg.menu and clicked and iskeypressed(0x12))
        pcall(updateMovement, myChar, myRoot, camera)
        local best, bestScore = nil, cfg.aimFov
        local count = 0
        for _, player in ipairs(Players:GetPlayers()) do
            local targetOk, t = pcall(getTarget, player, myRoot)
            if targetOk and t then
                if cfg.esp then
                    count = count + 1
                    if not espDrawings[count] then espDrawings[count] = newEspEntry() end
                    drawEsp(espDrawings[count], t, viewport)
                end
                if cfg.aim or cfg.triggerClick then
                    local dx, dy = t.aim.X - centerX, t.aim.Y - centerY
                    local score = math.sqrt(dx*dx + dy*dy)
                    if score < bestScore then best, bestScore = t, score end
                end
            end
        end
        if cfg.aim and best and ismouse2pressed() and isrbxactive() and not cfg.menu then
            local dx = clamp((best.aim.X - centerX) / cfg.smooth, -30, 30)
            local dy = clamp((best.aim.Y - centerY) / cfg.smooth, -30, 30)
            mousemoverel(round(dx), round(dy))
        end
        local targetClick = cfg.triggerClick and best and best.distance <= cfg.hitRange and bestScore <= 24 and ismouse2pressed()
        local rapidClick = cfg.fastClick and iskeypressed(0x56)
        if (targetClick or rapidClick) and isrbxactive() and not cfg.menu and tick() >= nextHitTime then
            nextHitTime = tick() + cfg.hitInterval / 1000
            pcall(mouse1click)
        end
    end)
    if not ok and tick() > nextWarn then
        warn("FALLEN / RIFT loop: " .. tostring(err))
        nextWarn = tick() + 5
    end
    wait(0.03)
end

restoreCollisions()
pcall(function() Workspace.CurrentCamera.FieldOfView = initialFov end)
if cameraFrameBefore then pcall(function() Workspace.CurrentCamera.CFrame = cameraFrameBefore end) end
for _, o in ipairs(allDrawings) do pcall(function() o:Remove() end) end
if _G.FallenRift == controller then _G.FallenRift = nil end
notify("RIFT unloaded.", "FALLEN / RIFT", 2)
