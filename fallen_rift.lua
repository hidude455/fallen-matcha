-- FALLEN / RIFT | Matcha external Lua VM
-- Place: Fallen Survival (10228136016)
-- Right Shift: show/hide menu  |  End: unload  |  Right mouse: hold aim assist

local PLACE_ID = 10228136016
if game.PlaceId ~= PLACE_ID then
    notify("Open Fallen Survival before running this script.", "FALLEN / RIFT", 4)
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
local Mouse = LocalPlayer:GetMouse()
local V2 = Vector2.new
local V3 = Vector3.new
local RGB = Color3.fromRGB

local theme = {
    bg = RGB(14, 15, 22), panel = RGB(21, 23, 33), raised = RGB(28, 31, 43),
    line = RGB(48, 51, 66), text = RGB(236, 237, 245), muted = RGB(137, 143, 166),
    violet = RGB(139, 75, 247), cyan = RGB(112, 209, 231), green = RGB(135, 214, 163),
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
    glowSelected = true, worldRange = 300, noclip = false, spider = false,
    climbSpeed = 18, cameraFov = 70
}

local allDrawings = {}
local pools = { Square = {}, Text = {}, Line = {}, Circle = {} }
local used = { Square = 0, Text = 0, Line = 0, Circle = 0 }
local espDrawings = {}
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
local function rect(x, y, w, h, color, corner)
    local o = pooled("Square")
    o.Position, o.Size, o.Color = V2(x, y), V2(w, h), color
    o.Filled, o.Transparency, o.Visible = true, 1, true
    pcall(function() o.Corner = corner or 0 end)
    pcall(function() o.ZIndex = 10 end)
    return o
end
local function styleText(o, size, bold, centered, outlined)
    local fontOk, font = pcall(function()
        return bold and Drawing.Fonts.SystemBold or Drawing.Fonts.Monospace
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
    o.Position, o.Text, o.Color = V2(x, y), value, color
    styleText(o, size, bold, false, false)
    o.Transparency, o.Visible = 1, true
    return o
end
local function line(x1, y1, x2, y2, color, thickness)
    local o = pooled("Line")
    o.From, o.To, o.Color, o.Thickness = V2(x1, y1), V2(x2, y2), color, thickness or 1
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
local function menuRow(x, y, w, title, hint, on, mx, my, click)
    rect(x, y, w, 53, theme.raised, 7)
    label(x + 13, y + 7, title, theme.text, 13, true)
    label(x + 13, y + 27, hint, theme.muted, 10)
    rect(x + w - 49, y + 16, 35, 20, on and accents[cfg.accent] or theme.line, 10)
    rect(x + w - (on and 30 or 45), y + 19, 14, 14, theme.white, 7)
    return click and pointIn(mx, my, x, y, w, 53)
end
local function sliderRow(x, y, w, title, hint, value, minValue, maxValue, mx, my, held)
    rect(x, y, w, 66, theme.raised, 7)
    label(x + 13, y + 7, title, theme.text, 13, true)
    label(x + 13, y + 27, hint, theme.muted, 10)
    label(x + w - 48, y + 7, tostring(value), accents[cfg.accent], 12, true)
    rect(x + 14, y + 51, w - 28, 3, theme.line, 2)
    local fill = (w - 28) * (value - minValue) / (maxValue - minValue)
    rect(x + 14, y + 51, fill, 3, accents[cfg.accent], 2)
    rect(x + 10 + fill, y + 47, 11, 11, theme.white, 6)
    if held and pointIn(mx, my, x + 5, y + 39, w - 10, 27) then
        return round(clamp(minValue + (mx - x - 14) / (w - 28) * (maxValue - minValue), minValue, maxValue))
    end
    return value
end

local menuPosition = { x = nil, y = nil, dragging = false, offsetX = 0, offsetY = 0 }
local function drawMenu(mx, my, click, held)
    if not cfg.menu then menuPosition.dragging = false; hideUnused(); return end
    local viewport = Workspace.CurrentCamera.ViewportSize
    if menuPosition.x == nil then
        menuPosition.x = math.floor((viewport.X - 590) / 2)
        menuPosition.y = math.floor((viewport.Y - 440) / 2)
    end
    local maxX, maxY = math.max(0, viewport.X - 590), math.max(0, viewport.Y - 440)
    menuPosition.x = clamp(menuPosition.x, 0, maxX)
    menuPosition.y = clamp(menuPosition.y, 0, maxY)
    local x, y = menuPosition.x, menuPosition.y
    if not held then menuPosition.dragging = false end
    if click and pointIn(mx, my, x + 550, y + 12, 30, 29) then
        cfg.menu = false
        menuPosition.dragging = false
        hideUnused()
        return
    end
    if click and (pointIn(mx, my, x, y, 139, 86) or pointIn(mx, my, x + 140, y, 410, 12)) then
        menuPosition.dragging = true
        menuPosition.offsetX, menuPosition.offsetY = mx - x, my - y
    end
    if menuPosition.dragging and held then
        x = clamp(mx - menuPosition.offsetX, 0, maxX)
        y = clamp(my - menuPosition.offsetY, 0, maxY)
        menuPosition.x, menuPosition.y = x, y
    end
    rect(x + 6, y + 7, 590, 440, theme.bg, 9)
    local base = rect(x, y, 590, 440, theme.panel, 8)
    base.Transparency = 0.94
    rect(x, y, 590, 3, accents[cfg.accent], 2)
    local side = rect(x, y, 139, 440, theme.bg, 7)
    side.Transparency = 0.95
    label(x + 19, y + 22, "FALLEN", theme.text, 19, true)
    label(x + 20, y + 49, "R I F T", accents[cfg.accent], 10, true)
    label(x + 20, y + 70, "DRAG TO MOVE", theme.muted, 9)
    line(x + 139, y + 1, x + 139, y + 439, theme.line)
    local tabNames = { "OVERVIEW", "AIMBOT", "VISUALS", "WORLD", "MISC" }
    for i = 1, 5 do
        local ty = y + 91 + (i - 1) * 47
        if i == cfg.tab then rect(x + 8, ty, 123, 36, accents[cfg.accent], 5) end
        label(x + 22, ty + 10, tabNames[i], i == cfg.tab and theme.white or theme.muted, 11, i == cfg.tab)
        if click and pointIn(mx, my, x + 8, ty, 123, 36) then cfg.tab = i end
    end
    label(x + 20, y + 382, "ALT+CLICK SELECT", theme.muted, 9)
    label(x + 20, y + 400, "RSHIFT  HIDE", theme.muted, 9)
    label(x + 20, y + 416, "END     UNLOAD", theme.muted, 9)

    local topNames = { "Home", "Aim", "Players", "Items", "Settings" }
    for i = 1, 5 do
        local tx = x + 153 + (i - 1) * 78
        if i == cfg.tab then rect(tx, y + 13, 72, 27, accents[cfg.accent], 13) end
        label(tx + 10, y + 19, topNames[i], i == cfg.tab and theme.white or theme.muted, 10, i == cfg.tab)
        if click and pointIn(mx, my, tx, y + 13, 72, 27) then cfg.tab = i end
    end
    rect(x + 550, y + 13, 30, 27, theme.raised, 5)
    label(x + 560, y + 19, "X", theme.coral, 11, true)
    line(x + 140, y + 51, x + 589, y + 51, theme.line)
    local bx, by, bw = x + 161, y + 61, 405
    label(bx, by, tabNames[cfg.tab], theme.text, 18, true)
    label(bx, by + 26, "Fallen Survival / external control", theme.muted, 10)
    line(bx, by + 52, bx + bw, by + 52, theme.line)
    local rowY = by + 68
    if cfg.tab == 1 then
        rect(bx, rowY, bw, 71, theme.raised, 7)
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
        if menuRow(bx, rowY, bw, "Show teammates", "Include same-team players", cfg.teammates, mx, my, click) then cfg.teammates = not cfg.teammates end
        rowY = rowY + 57
        if menuRow(bx, rowY, bw, "Noclip", "Local character collision", cfg.noclip, mx, my, click) then cfg.noclip = not cfg.noclip end
        rowY = rowY + 57
        if menuRow(bx, rowY, bw, "Spider climb", "Hold W into a wall to rise", cfg.spider, mx, my, click) then cfg.spider = not cfg.spider end
        rowY = rowY + 58
        cfg.cameraFov = sliderRow(bx, rowY, bw, "Camera FOV", "Restore on unload", cfg.cameraFov, 55, 110, mx, my, held)
        rowY = rowY + 75
        cfg.worldRange = sliderRow(bx, rowY, bw, "World range", "Maximum resource distance", cfg.worldRange, 50, 600, mx, my, held)
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
    local e = { ring = newDraw("Circle"), text = newDraw("Text") }
    e.ring.Radius, e.ring.NumSides, e.ring.Thickness = 5, 16, 2
    styleText(e.text, 11, false, true, true)
    return e
end
local function hideWorld()
    for _, e in ipairs(worldDrawings) do e.ring.Visible, e.text.Visible = false, false end
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
    pcall(function() camera.FieldOfView = cfg.cameraFov end)
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

local fovCircle = newDraw("Circle")
fovCircle.NumSides, fovCircle.Thickness = 64, 1
local nextWarn = 0
local rightShiftWasDown, endWasDown, mouseWasDown = false, false, false
notify("RIFT loaded. Right Shift opens menu; End unloads.", "FALLEN / RIFT", 4)

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
        fovCircle.Position, fovCircle.Radius, fovCircle.Color = V2(centerX, centerY), cfg.aimFov, accents[cfg.accent]
        fovCircle.Visible = cfg.aim and cfg.showFov

        for _, e in ipairs(espDrawings) do hideEsp(e) end
        hideWorld()
        local myChar = LocalPlayer.Character
        local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar.PrimaryPart)
        pcall(function() camera.FieldOfView = cfg.cameraFov end)
        if not myRoot then return end
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
                if cfg.aim then
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
    end)
    if not ok and tick() > nextWarn then
        warn("FALLEN / RIFT loop: " .. tostring(err))
        nextWarn = tick() + 5
    end
    wait(0.03)
end

restoreCollisions()
pcall(function() Workspace.CurrentCamera.FieldOfView = initialFov end)
for _, o in ipairs(allDrawings) do pcall(function() o:Remove() end) end
if _G.FallenRift == controller then _G.FallenRift = nil end
notify("RIFT unloaded.", "FALLEN / RIFT", 2)
