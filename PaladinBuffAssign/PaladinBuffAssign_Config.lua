--[[
    PaladinBuffAssign_Config
    Configuration panel for PaladinBuffAssign.
--]]

local addonName = "PaladinBuffAssign"
local PBA = _G[addonName]
local L = PBA.L

local cfgFrame = nil
local refreshers = {}

local function AddRefresher(fn)
    refreshers[#refreshers + 1] = fn
end

local function MakeSection(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text)
    return 26
end

local function MakeCheckbox(parent, text, x, y, get, set)
    local name = addonName .. "CfgCB" .. (#refreshers + 1)
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local lab = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lab:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    lab:SetJustifyH("LEFT")
    lab:SetText(text)
    cb:SetHitRectInsets(0, -(lab:GetStringWidth() + 8), 0, 0)
    cb:SetScript("OnClick", function(self)
        set(not not self:GetChecked())
        PBA:RebuildBars()
        PBA:UpdateAnnounceButton()
        PBA:UpdateGearVisibility()
        PBA:ApplyFrameSettings()
    end)
    cb.refresh = function()
        cb:SetChecked(get())
    end
    AddRefresher(cb.refresh)
    return 24
end

local function MakeSlider(parent, key, label, x, y, minv, maxv, step, get, set)
    local name = addonName .. "CfgS_" .. key
    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetWidth(210)
    s:SetHeight(16)
    s:SetMinMaxValues(minv, maxv)
    s:SetValueStep(step)
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 14)
    local st = _G[name .. "Text"]
    if st then st:SetText(label) end
    local sLow = _G[name .. "Low"]
    if sLow then sLow:SetText(string.format("%g", minv)) end
    local sHigh = _G[name .. "High"]
    if sHigh then sHigh:SetText(string.format("%g", maxv)) end
    if not st then
        local lab = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lab:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 4)
        lab:SetText(label)
    end

    local val = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val:SetPoint("LEFT", s, "RIGHT", 10, 0)
    val:SetWidth(46)
    val:SetJustifyH("LEFT")
    local fmt = (step < 1) and "%.2f" or "%d"

    s:SetScript("OnValueChanged", function(self, value)
        local v = math.floor(value / step + 0.5) * step
        v = math.floor(v * 100 + 0.5) / 100
        if v ~= self._lock then
            self._lock = v
            self:SetValue(v)
        end
        val:SetText(string.format(fmt, v))
        if get() ~= v then
            set(v)
            PBA:ApplyFrameSettings()
            PBA:RebuildBars()
        end
    end)
    s.refresh = function()
        local v = get()
        s._lock = v
        s:SetValue(v)
        val:SetText(string.format(fmt, v))
    end
    AddRefresher(s.refresh)
    return 48
end

local function MakeDropdown(parent, key, label, x, y, items, get, set)
    local lab = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lab:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lab:SetText(label)

    local name = addonName .. "CfgDD_" .. key
    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", parent, "TOPLEFT", x - 16, y - 20)
    UIDropDownMenu_SetWidth(dd, 170)

    UIDropDownMenu_Initialize(dd, function(_, level)
        for _, item in ipairs(items) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.text
            info.func = function()
                set(item.value)
                UIDropDownMenu_SetText(dd, item.text)
                CloseDropDownMenus()
                PBA:RebuildBars()
            end
            info.checked = (get() == item.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    dd.refresh = function()
        local cur = get()
        for _, item in ipairs(items) do
            if item.value == cur then
                UIDropDownMenu_SetText(dd, item.text)
                return
            end
        end
    end
    AddRefresher(dd.refresh)
    return 48
end

local function MakeButton(parent, text, x, y, width, onclick)
    local name = addonName .. "CfgBtn" .. (#refreshers + 1)
    local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    b:SetWidth(width or 110)
    b:SetHeight(22)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", onclick)
    return b
end

function PBA:CreateConfig()
    if cfgFrame then
        self:RefreshConfigUI()
        if cfgFrame:IsShown() then
            cfgFrame:Hide()
        else
            cfgFrame:Show()
        end
        return
    end

    local d = PBA.db
    local f = CreateFrame("Frame", addonName .. "ConfigFrame", UIParent)
    f:SetWidth(740)
    f:SetHeight(650)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(s) s:StartMoving() end)
    f:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() end)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    cfgFrame = f

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -18)
    title:SetText(L.title)

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)
    hint:SetText("/pba — toggle this window | /pba lock | /pba unlock | /pba announce | /pba reset | /pba refresh")

    local x1, x2 = 28, 390
    local y = -52

    -- ЛЕВАЯ КОЛОНКА
    y = y - MakeSection(f, "General", x1, y)
    y = y - MakeCheckbox(f, L.enabled, x1 + 8, y,
        function() return d.enabled end,
        function(v) d.enabled = v; PBA:RebuildBars() end)
    y = y - MakeCheckbox(f, L.groupOnly, x1 + 8, y,
        function() return d.groupOnly end,
        function(v) d.groupOnly = v; PBA:RebuildBars() end)
    y = y - MakeCheckbox(f, L.locked, x1 + 8, y,
        function() return d.locked end,
        function(v) d.locked = v; PBA:ApplyFrameSettings() end)
    y = y - MakeCheckbox(f, L.minimal, x1 + 8, y,
        function() return d.minimal end,
        function(v) d.minimal = v; PBA:UpdateGearVisibility(); PBA:ApplyFrameSettings() end)

    y = y - 8
    y = y - MakeSection(f, "Appearance", x1, y)
    y = y - MakeSlider(f, "width", L.width, x1 + 8, y, 120, 500, 1,
        function() return d.width end, function(v) d.width = v end)
    y = y - MakeSlider(f, "height", L.height, x1 + 8, y, 20, 80, 1,
        function() return d.height end, function(v) d.height = v end)
    y = y - MakeSlider(f, "scale", L.scale, x1 + 8, y, 0.5, 2, 0.05,
        function() return d.scale end, function(v) d.scale = v end)
    y = y - MakeSlider(f, "spacing", L.spacing, x1 + 8, y, 0, 20, 1,
        function() return d.spacing end, function(v) d.spacing = v end)
    y = y - MakeSlider(f, "barAlpha", L.barAlpha, x1 + 8, y, 0.1, 1, 0.05,
        function() return d.barAlpha end, function(v) d.barAlpha = v end)

    -- ПРАВАЯ КОЛОНКА
    local ry = -52
    ry = ry - MakeSection(f, "Menu", x2, ry)
    ry = ry - MakeDropdown(f, "menudir", L.menuDirection, x2 + 8, ry, {
        { text = L.dirLeft, value = "left" },
        { text = L.dirRight, value = "right" },
    }, function() return d.menuDirection end, function(v) d.menuDirection = v end)

    ry = ry - MakeSlider(f, "menuAlpha", L.menuAlpha, x2 + 8, ry, 0.1, 1, 0.05,
        function() return d.menuAlpha end, function(v) d.menuAlpha = v end)

    -- [FIX] Слайдер «Проверка спека (сек)» удалён — интервал зашит в код (5 сек).
    -- Секция «Buff name display» теперь идёт сразу после menuAlpha.

    ry = ry - 8
    ry = ry - MakeSection(f, "Buff name display", x2, ry)
    ry = ry - MakeDropdown(f, "buffnamemode", L.buffNameMode, x2 + 8, ry, {
        { text = L.bmIcon, value = "icon" },
        { text = L.bmShort, value = "short" },
        { text = L.bmFull, value = "full" },
    }, function() return d.buffNameMode end, function(v) d.buffNameMode = v end)

    ry = ry - 32
    ry = ry - MakeDropdown(f, "announcenamemode", L.announceNameMode, x2 + 8, ry, {
        { text = L.anShort, value = "short" },
        { text = L.anFull, value = "full" },
    }, function() return d.announceNameMode end, function(v) d.announceNameMode = v end)

    local closeBtn = MakeButton(f, "Close", 0, 0, 100, function() f:Hide() end)
    closeBtn:ClearAllPoints()
    closeBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 16)

    self:RefreshConfigUI()
end

function PBA:RefreshConfigUI()
    for i = 1, #refreshers do
        refreshers[i]()
    end
end

function PBA:ToggleConfig()
    if not cfgFrame then
        self:CreateConfig()
    end
    if cfgFrame:IsShown() then
        cfgFrame:Hide()
    else
        cfgFrame:Show()
        self:RefreshConfigUI()
    end
end