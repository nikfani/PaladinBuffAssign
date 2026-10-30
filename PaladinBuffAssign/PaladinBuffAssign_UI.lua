--[[
    PaladinBuffAssign_UI
    Bar UI, context menus, announce button, gear frame.
--]]

local addonName = "PaladinBuffAssign"
local PBA = _G[addonName]
local L = PBA.L

-- ==================== HELPERS ====================
local rows = {}

local function SetSafeFont(fs, path, size, outline)
    local ok = pcall(function() fs:SetFont(path, size, outline) end)
    if not ok then
        pcall(function() fs:SetFont("Fonts\\FRIZQT__.TTF", size, outline) end)
    end
end

local function GetSpecColor(spec)
    if spec == "Protection" then return 0.70, 0.30, 0.30 end
    if spec == "Holy" then return 0.30, 0.70, 0.30 end
    if spec == "Retribution" then return 0.90, 0.70, 0.10 end
    return 0.60, 0.60, 0.60
end

local function db()
    return PBA.db
end

-- ==================== MAIN FRAME ====================
function PBA:CreateMain()
    if self.main then return end
    local d = db()
    local main = CreateFrame("Frame", addonName .. "Frame", UIParent)
    main:SetClampedToScreen(true)
    main:SetMovable(true)
    main:SetFrameStrata("MEDIUM")
    -- [FIX] Сразу применяем сохранённые масштаб и позицию.
    -- Без этого фрейм создавался в (0,0) и был скрыт за другими элементами UI,
    -- пока не вызовут ApplyFrameSettings (например, из конфига).
    main:SetScale(d.scale or 1.0)
    main:SetPoint(d.point or "CENTER", UIParent, d.relPoint or "CENTER", d.x or 0, d.y or 0)
    main:EnableMouse(not d.locked)
    main:RegisterForDrag("LeftButton")
    main:SetScript("OnDragStart", function(f)
        if menuFrame then menuFrame:Hide() end
        if not d.locked then f:StartMoving() end
    end)
    main:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local point, _, relPoint, x, y = f:GetPoint()
        d.point = point or "CENTER"
        d.relPoint = relPoint or "CENTER"
        d.x = x or 0
        d.y = y or 0
    end)
    self.main = main
end

function PBA:ApplyFrameSettings()
    local d = db()
    local main = self.main
    if not main then return end
    main:SetScale(d.scale)
    main:ClearAllPoints()
    main:SetPoint(d.point or "CENTER", UIParent, d.relPoint or "CENTER", d.x or 0, d.y or 0)
    main:EnableMouse(not d.locked)
    if d.minimal then
        main:Hide()
    else
        local hasPals = false
        for _ in pairs(PBA.paladins) do hasPals = true break end
        if hasPals then main:Show() else main:Hide() end
    end
end

-- ==================== BAR UI ====================
function PBA:RebuildBars()
    local d = db()
    local main = self.main
    if not main then return end

    if not d.enabled then
        main:Hide()
        return
    end
    if d.groupOnly and GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then
        main:Hide()
        return
    end

    local paladinNames = {}
    for name, _ in pairs(PBA.paladins) do
        paladinNames[#paladinNames + 1] = name
    end
    table.sort(paladinNames)

    if #paladinNames == 0 then
        main:Hide()
        return
    end

    local h = d.height
    local spacing = d.spacing
    local w = d.width

    main:SetWidth(w)
    main:SetHeight(#paladinNames * (h + spacing) - spacing)
    if not d.minimal then
        main:Show()
    end

    local i = 1
    for _, name in ipairs(paladinNames) do
        local row = rows[i]
        if not row then
            row = self:AcquireRow(i)
        end
        rows[i] = row
        row:Show()

        local p = PBA.paladins[name]
        row:SetHeight(h)
        row:SetWidth(w)
        row:ClearAllPoints()
        if i == 1 then
            row:SetPoint("TOPLEFT", main, "TOPLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -spacing)
        end

        row.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        local r, g, b = GetSpecColor(p.spec)
        row.bg:SetVertexColor(r * 0.30, g * 0.30, b * 0.30, d.barAlpha or 0.85)

        local specIcon = PBA:GetSpecIcon(p.spec)
        row.specIcon:SetTexture(specIcon)
        row.specIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.specIcon:Show()

        row.name:SetText(name)
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS.PALADIN or { r = 1, g = 0.5, b = 0.75 }
        row.name:SetTextColor(color.r, color.g, color.b, 1)
        row.name:SetPoint("LEFT", row.specIcon, "RIGHT", 6, 0)

        local buffs = PBA:GetPaladinBuffs(name)
        local buffNameMode = d.buffNameMode or "full"

        for _, iconTex in ipairs(row.buffIcons) do
            iconTex:Hide()
            iconTex:SetTexture("")
            iconTex:SetTexCoord(0, 1, 0, 1)
        end
        wipe(row.buffIcons)
        row.buffText:Hide()

        if #buffs > 0 then
            local iconSize = h - 4
            local offsetX = 0
            for idx, bk in ipairs(buffs) do
                local iconTex = row.buffIcons[idx]
                if not iconTex then
                    iconTex = row:CreateTexture(nil, "ARTWORK")
                    iconTex:SetWidth(iconSize)
                    iconTex:SetHeight(iconSize)
                    table.insert(row.buffIcons, iconTex)
                end
                iconTex:SetTexture(PBA:GetBuffIcon(bk))
                iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                iconTex:ClearAllPoints()
                iconTex:SetPoint("RIGHT", row, "RIGHT", -4 - offsetX, 0)
                iconTex:Show()
                offsetX = offsetX + iconSize + 4
            end

            local parts = {}
            for _, bk in ipairs(buffs) do
                parts[#parts + 1] = PBA:FormatBuffName(bk, buffNameMode)
            end
            local dispText = table.concat(parts, ", ")

            if buffNameMode == "icon" then
                row.buffText:Hide()
            else
                row.buffText:SetText(dispText)
                row.buffText:Show()
                row.buffText:SetPoint("RIGHT", row, "RIGHT", -4 - offsetX, 0)
                row.buffText:SetJustifyH("RIGHT")
                row.buffText:SetTextColor(0.9, 0.9, 0.3, 1)
            end
        else
            local iconTex = row.buffIcons[1]
            if not iconTex then
                iconTex = row:CreateTexture(nil, "ARTWORK")
                iconTex:SetWidth(h - 4)
                iconTex:SetHeight(h - 4)
                table.insert(row.buffIcons, iconTex)
            end
            iconTex:SetTexture("Interface\\Buttons\\UI-StopButton")
            iconTex:SetTexCoord(0, 1, 0, 1)
            iconTex:ClearAllPoints()
            iconTex:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            iconTex:Show()
        end

        row.paladinName = name
        i = i + 1
    end

    for j = i, #rows do
        rows[j]:Hide()
    end

    self:UpdateAnnounceButton()
end

function PBA:AcquireRow(index)
    local row = rows[index]
    if row then return row end

    local d = db()
    local main = self.main
    local h = d.height
    local w = d.width

    row = CreateFrame("Button", addonName .. "Row" .. index, main)
    row:SetHeight(h)
    row:SetWidth(w)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:RegisterForDrag("LeftButton")

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.bg:SetVertexColor(0.1, 0.1, 0.1, 0.85)

    row.specIcon = row:CreateTexture(nil, "ARTWORK")
    row.specIcon:SetWidth(h - 4)
    row.specIcon:SetHeight(h - 4)
    row.specIcon:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.specIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    row.name = row:CreateFontString(nil, "OVERLAY")
    SetSafeFont(row.name, "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    row.name:SetPoint("LEFT", row.specIcon, "RIGHT", 6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetJustifyV("MIDDLE")

    row.buffIcons = {}

    row.buffText = row:CreateFontString(nil, "OVERLAY")
    SetSafeFont(row.buffText, "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    row.buffText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.buffText:SetJustifyH("RIGHT")
    row.buffText:SetJustifyV("MIDDLE")

    row:SetScript("OnEnter", function(self) row:LockHighlight() end)
    row:SetScript("OnLeave", function(self) row:UnlockHighlight() end)

    row:SetScript("OnClick", function(self, button)
        if button ~= "LeftButton" and button ~= "RightButton" then return end
        if menuFrame and menuFrame:IsShown() and menuFrame.paladinName == self.paladinName then
            menuFrame:Hide()
        else
            PBA:ShowMenu(self.paladinName, self, d.menuDirection)
        end
    end)

    row:SetScript("OnDragStart", function(self)
        if menuFrame then menuFrame:Hide() end
        if not d.locked then PBA.main:StartMoving() end
    end)
    row:SetScript("OnDragStop", function(self)
        PBA.main:StopMovingOrSizing()
        local point, _, relPoint, x, y = PBA.main:GetPoint()
        d.point = point or "CENTER"
        d.relPoint = relPoint or "CENTER"
        d.x = x or 0
        d.y = y or 0
    end)

    rows[index] = row
    return row
end

-- ==================== CONTEXT MENU (HORIZONTAL) ====================
local menuFrame = nil

local function HideMenu()
    if menuFrame then menuFrame:Hide() end
end

function PBA:ShowMenu(paladinName, anchorFrame, direction)
    HideMenu()

    local d = db()
    local p = PBA.paladins[paladinName]
    if not p then return end

    local assignable = PBA:GetAssignableBuffs(paladinName)
    if #assignable == 0 then return end

    -- === Размеры (горизонтальная полоса) ===
    local itemH      = d.height         -- точно = высота строки (вертикальное выравнивание)
    local padding    = 0                 -- без внутреннего паддинга — меню точно по высоте строки
    local itemSpacing = 2                -- маленький зазор между иконками-кнопками

    local buffNameMode = d.buffNameMode or "full"
    local itemW
    if buffNameMode == "icon" then
        itemW = itemH
    else
        -- Ширина по самой длинной строке (по 8px на символ — запас под кириллицу)
        local maxTextWidth = 0
        for _, buffKey in ipairs(assignable) do
            local text = PBA:FormatBuffName(buffKey, buffNameMode)
            if text and text ~= "" then
                maxTextWidth = math.max(maxTextWidth, #text * 8 + 12)
            end
        end
        -- icon(2 + itemH-4) + gap 6 + text + правый паддинг 4
        itemW = itemH + 8 + maxTextWidth
    end

    local numItems = #assignable
    local mWidth   = padding * 2 + numItems * itemW + (numItems - 1) * itemSpacing
    local mHeight  = itemH + padding * 2

    -- === Создаём контейнер (один раз) ===
    if not menuFrame then
        menuFrame = CreateFrame("Frame", addonName .. "Menu", PBA.main)
        menuFrame:SetFrameStrata("DIALOG")
        menuFrame:SetClampedToScreen(true)
        menuFrame:EnableMouse(true)
        menuFrame:SetToplevel(true)
        menuFrame.bg = menuFrame:CreateTexture(nil, "BACKGROUND")
        menuFrame.bg:SetAllPoints(menuFrame)
        menuFrame.bg:SetTexture(0, 0, 0, d.menuAlpha or 0.90)
        menuFrame.border = menuFrame:CreateTexture(nil, "BORDER")
        menuFrame.border:SetAllPoints(menuFrame)
        menuFrame.border:SetTexture(0.2, 0.2, 0.2, 1)
    end
    menuFrame.bg:SetTexture(0, 0, 0, d.menuAlpha or 0.90)
    menuFrame.paladinName = paladinName

    menuFrame:ClearAllPoints()
    menuFrame:SetWidth(mWidth)
    menuFrame:SetHeight(mHeight)

    -- === Позиционирование ===
    -- По горизонтали: слева или справа от строки с зазором 4px.
    -- По вертикали: центр меню = центр строки (на уровне бара).
    local aLeft   = anchorFrame:GetLeft()
    local aRight  = anchorFrame:GetRight()
    local aBottom = anchorFrame:GetBottom()
    local aHeight = anchorFrame:GetHeight()
    local mLeft   = PBA.main:GetLeft()
    local mBottom = PBA.main:GetBottom()

    local mx
    if direction == "left" then
        mx = aLeft - mLeft - mWidth - 4
    else
        mx = aRight - mLeft + 4
    end
    -- Вертикальное центрирование: bottom + (rowH - menuH)/2
    local my = (aBottom - mBottom) + (aHeight - mHeight) / 2

    menuFrame:SetPoint("BOTTOMLEFT", PBA.main, "BOTTOMLEFT", mx, my)
    menuFrame:Show()

    -- === Заполняем элементами (горизонтально) ===
    if not menuFrame.items then menuFrame.items = {} end
    for _, item in ipairs(menuFrame.items) do item:Hide() end

    local rowIdx = 0
    for _, buffKey in ipairs(assignable) do
        rowIdx = rowIdx + 1
        local item = menuFrame.items[rowIdx]
        if not item then
            item = CreateFrame("Button", nil, menuFrame)
            item:EnableMouse(true)

            item.bg = item:CreateTexture(nil, "BACKGROUND")
            item.bg:SetAllPoints(item)
            item.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
            item.bg:SetVertexColor(0.15, 0.15, 0.15, 0.9)

            item.icon = item:CreateTexture(nil, "ARTWORK")
            item.icon:SetWidth(itemH - 4)
            item.icon:SetHeight(itemH - 4)
            item.icon:SetPoint("LEFT", item, "LEFT", 2, 0)

            item.text = item:CreateFontString(nil, "OVERLAY")
            SetSafeFont(item.text, "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
            item.text:SetJustifyH("LEFT")

            item:SetScript("OnEnter", function(self)
                self.bg:SetVertexColor(0.3, 0.3, 0.3, 0.9)
            end)
            item:SetScript("OnLeave", function(self)
                if PBA:HasBuff(self.paladinName, self.buffKey) then
                    self.bg:SetVertexColor(0.4, 0.35, 0.1, 0.95)
                    self.text:SetTextColor(1, 0.9, 0.4, 1)
                else
                    self.bg:SetVertexColor(0.15, 0.15, 0.15, 0.9)
                    self.text:SetTextColor(1, 1, 1, 1)
                end
            end)
            item:SetScript("OnClick", function(self, button)
                if button == "LeftButton" then
                    PBA:AssignBuff(self.paladinName, self.buffKey)
                    menuFrame:Hide()
                end
            end)

            menuFrame.items[rowIdx] = item
        end

        item.paladinName = paladinName
        item.buffKey     = buffKey

        -- Горизонтальное размещение: слот 0, 1, 2, ... слева-направо
        item:ClearAllPoints()
        item:SetWidth(itemW)
        item:SetHeight(itemH)
        item:SetPoint("LEFT", menuFrame, "LEFT",
            padding + (rowIdx - 1) * (itemW + itemSpacing), 0)
        item:Show()

        item.icon:SetTexture(PBA:GetBuffIcon(buffKey))
        item.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        local dispText = PBA:FormatBuffName(buffKey, buffNameMode)
        if buffNameMode == "icon" then
            item.text:Hide()
            item.icon:ClearAllPoints()
            item.icon:SetPoint("CENTER", item, "CENTER", 0, 0)
        else
            item.text:Show()
            item.icon:ClearAllPoints()
            item.icon:SetPoint("LEFT", item, "LEFT", 2, 0)
            item.text:ClearAllPoints()
            item.text:SetPoint("LEFT", item.icon, "RIGHT", 6, 0)
            item.text:SetPoint("RIGHT", item, "RIGHT", -4, 0)
            item.text:SetText(dispText)
        end

        if PBA:HasBuff(paladinName, buffKey) then
            item.bg:SetVertexColor(0.4, 0.35, 0.1, 0.95)
            item.text:SetTextColor(1, 0.9, 0.4, 1)
        else
            item.bg:SetVertexColor(0.15, 0.15, 0.15, 0.9)
            item.text:SetTextColor(1, 1, 1, 1)
        end
    end
end

-- ==================== ANNOUNCE BUTTON ====================
local announceBtn = nil

function PBA:UpdateAnnounceButton()
    local d = db()
    if not d then return end

    local show = self:AnyBuffAssigned()

    if not announceBtn then
        announceBtn = CreateFrame("Button", addonName .. "AnnounceBtn", PBA.main, "UIPanelButtonTemplate")
        announceBtn:SetWidth(120)
        announceBtn:SetHeight(22)
        announceBtn:SetText(L.announce)
        announceBtn:SetFrameStrata("DIALOG")
        announceBtn:SetScript("OnClick", function()
            PBA:Announce()
        end)
        announceBtn:Hide()
    end

    announceBtn:SetParent(PBA.main)
    announceBtn:ClearAllPoints()
    announceBtn:SetPoint("TOPLEFT", PBA.main, "BOTTOMLEFT", 0, -2)

    if show and (not d.minimal or PBA.main:IsShown()) then
        announceBtn:Show()
    else
        announceBtn:Hide()
    end
end

-- ==================== SLASH: toggle config ====================
function PBA:ToggleConfig()
    if PaladinBuffAssign_Config and PaladinBuffAssign_Config.Toggle then
        PaladinBuffAssign_Config.Toggle()
    end
end