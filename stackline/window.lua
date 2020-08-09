local _ = require 'stackline.utils.utils'
local u = require 'stackline.utils.underscore'

function makeStackId(win) -- {{{
    -- stackId is top-left window frame coordinates
    -- example: "302|35|63|1185|741"
    -- OLD definition:
    --    generate stackId from spaceId & frame values
    --    example (old): "302|35|63|1185|741"
    local frame = win:frame():floor()
    local x = frame.x
    local y = frame.y
    local w = frame.w
    local h = frame.h
    return {
        topLeft = table.concat({x, y}, '|'),
        stackId = table.concat({x, y, w, h}, '|'),
    }
end -- }}}

-- ┌───────────────┐
-- │ Window module │
-- └───────────────┘

local Window = {}

-- luacheck: ignore
function Window:new(hsWin) -- {{{
    local ws = {
        -- title = w:title(), -- window title for debug only (string)
        app = hsWin:application():name(), -- app name (string)
        id = hsWin:id(), -- window id (string) NOTE: the ID is the same as yabai! So we could interopt if we need to
        frame = hsWin:frame(), -- x,y,w,h of window (table)
        stackIdx = hsWin.stackIdx, -- only from yabai, unfort.
        stackId = makeStackId(hsWin).stackId, -- "{{x}|{y}|{w}|{h}" e.g., "35|63|1185|741" (string)
        topLeft = makeStackId(hsWin).topLeft, -- "{{x}|{y}" e.g., "35|63" (string)
        _win = hsWin, -- hs.window object (table)
        indicator = nil, -- the canvas element (table)
    }

    setmetatable(ws, self)
    self.__index = self
    return ws
end -- }}}

function Window:setStackIdx() -- {{{
    -- FIXME: Too slow. Probably want to query all windows on space, pluck out
    -- their stack indexes with jq, & send to hammerspoon to merge with windows.

    -- _.pheader('running setStackIdx for: ' .. self.id)
    local scriptPath = hs.configdir .. '/stackline/bin/yabai-get-stack-idx'
    hs.task.new("/usr/local/bin/dash", function(_code, stdout, stderr)
        local stackIdx = tonumber(stdout)
        self.stackIdx = stackIdx
        -- print('stack idx for ', self.id, ' is ', stackIdx)
    end, {scriptPath, tostring(self.id)}):start():waitUntilExit()
end -- }}}

function Window:isFocused() -- {{{
    local focusedWin = hs.window.focusedWindow()
    if focusedWin == nil then
        return false
    end
    local isFocused = self.id == focusedWin:id()
    return isFocused
end -- }}}

-- function Window.__eq(a, b) -- {{{
--     -- FIXME: unused as of 2020-07-31
--     local t1 = a.id
--     local t2 = b.id
--     print('Window.__eq metamethod called:', a.id, a.focused, ' < VS: > ', t2,
--           b.focused)
--     local existComp = {id = a.id, frame = a.frameFlat, focused = a.focused}
--     local currComp = {id = b.id, frame = b.frameFlat, focused = b.focused}
--     -- _.p('A Compare:', existComp)
--     -- _.p('B Compare:', currComp)
--     local isEqual = _.isEqual(existComp, currComp)
--     return isEqual
-- end -- }}}

function Window:getScreenSide() -- {{{
    -- (sFrame.w - (wFrame.x + wFrame.w)) / sFrame.w
    local screenWidth = self._win:screen():fullFrame().w
    local frame = self.frame
    local percRight = 1 - ((screenWidth - (frame.x + frame.w)) / screenWidth)
    local percLeft = (screenWidth - frame.x) / screenWidth
    local side = (percRight > 0.95 and percLeft < 0.95) and 'right' or 'left'

    return side

    -- TODO: find a way to use hs.window.filter.windowsTo{Dir} 
    -- to determine side instead of percLeft/Right ↑
    --    https://www.hammerspoon.org/docs/hs.window.filter.html#windowsToWest
    --      wfd:windowsToWest(self._win)
    --    https://www.hammerspoon.org/docs/hs.window.html#windowsToWest
    --      self._win:windowsToSouth()
end -- }}}

-- TODO: ↑ Convert to .__eq metatable
function Window:setNeedsUpdated(extant) -- {{{
    local isEqual = _.isEqual(existComp, currComp)
    self.needsUpdated = not isEqual
end -- }}}

function Window:setupIndicator(Icons) -- {{{
    -- Config
    local showIcons = stacksMgr:getShowIconsState()

    -- Padding
    self.padding = 4
    self.iconPadding = 4

    -- Size
    self.aspectRatio = 6 -- determines width of pills when showIcons = false
    self.size = 32
    self.width = showIcons and self.size or (self.size / self.aspectRatio)

    -- Position
    self.offsetY = 2
    self.offsetX = 4

    -- Overlapped with window + percent top offset
    -- self.offsetY = self.frame.h * 0.1
    -- self.offsetX = -(self.width / 2)

    -- Roundness
    self.indicatorRadius = 3
    self.iconRadius = self.width / 4.0

    -- Fade-in/out duration
    self.fadeDuration = 0.2

    -- Display indicators on 
    --   left edge of windows on the left side of the screen, &
    --   right edge of windows on the right side of the screen
    local side = self:getScreenSide()
    local xval = nil
    if side == 'right' then
        xval = (self.frame.x + self.frame.w) + self.offsetX
    else
        xval = self.frame.x - (self.width + self.offsetX)
    end

    -- Set canvas to fill entire screen
    self.canvas_frame = self._win:screen():frame()

    -- Store  canvas elements indexes to reference via :elementAttribute()
    -- https://www.hammerspoon.org/docs/hs.canvas.html#elementAttribute
    self.rectIdx = 1
    self.iconIdx = 2

    -- NOTE: self.stackIdx comes from yabai
    self.indicator_rect = {
        x = xval,
        y = self.frame.y + ((self.stackIdx - 1) * self.size * 1.1),
        w = self.width,
        h = self.size,
    }

    self.icon_rect = {
        x = xval + self.iconPadding,
        y = self.indicator_rect.y + self.iconPadding,
        w = self.indicator_rect.w - (self.iconPadding * 2),
        h = self.indicator_rect.h - (self.iconPadding * 2),
    }
end -- }}}

function Window:drawIndicator(overrideOpts, focusedHint) -- {{{
    local defaultOpts = {
        shouldFade = true,
        alphaFocused = 1,
        alphaUnfocused = 0.33,
    }

    local opts = u.extend(defaultOpts, overrideOpts or {})

    -- Color
    self.colorFocused = {white = 0.9, alpha = opts.alphaFocused}
    self.colorUnfocused = {white = 0.9, alpha = opts.alphaUnfocused}

    -- Unfocused icons less transparent than bg color, but no more than 1
    self.iconAlphaFocused = opts.alphaFocused
    self.iconAlphaUnfocused = math.min(opts.alphaUnfocused * 2, 1)

    self.shadowOpts = {blur = self.focus}

    local showIcons = stacksMgr:getShowIconsState()
    local radius = showIcons and self.iconRadius or self.indicatorRadius
    local fadeDuration = opts.shouldFade and self.fadeDuration or 0

    self.focus = self:isFocused()
    -- PROFILE: 0.0123s / 75 (0.0002s) :: isFocused 

    if self.indicator then
        self.indicator:delete()
    end

    self.indicator = hs.canvas.new(self.canvas_frame)

    self.currStyle = {
        fillColor = self.focus and self.colorFocused or self.colorUnfocused,
        imageAlpha = self.focus and self.iconAlphaFocused or
            self.iconAlphaUnfocused,
        shadow = {
            blurRadius = 20.0,
            color = {alpha = 1 / 5},
            offset = {h = -2.0, w = 0.0},
        },
    }

    self.indicator:insertElement({
        type = "rectangle",
        action = "fill",
        fillColor = self.currStyle.fillColor,
        frame = self.indicator_rect,
        roundedRectRadii = {xRadius = radius, yRadius = radius},
        padding = 60,
        withShadow = true,
    }, self.rectIdx)

    if showIcons then
        -- TODO: Figure out how to prevent clipping when adding a subtle shadow
        -- to the icon to help distinguish icons with a near-white edge.
        self.indicator:insertElement({
            type = "image",
            image = self:iconFromAppName(),
            frame = self.icon_rect,
            imageAlpha = self.currStyle.imageAlpha,
        }, self.iconIdx)
    end

    self.indicator:show(fadeDuration)
end -- }}}

function Window:redrawIndicator(overrideOpts, isFocused) -- {{{
    _.pheader('redraw')
    print(self.id, self.app, isFocused)
    -- bail early if there's nothing to do
    if isFocused == self.focus then
        return false
    else
        self.focus = isFocused
    end

    local set = _.partial(self.indicator.elementAttribute, self.indicator)
    local setRect = _.partial(set, self.rectIdx)
    local setIcon = _.partial(set, self.iconIdx)

    local fillColor = self.focus and self.colorFocused or self.colorUnfocused
    local imageAlpha = self.focus and self.iconAlphaFocused or
                           self.iconAlphaUnfocused

    setRect('fillColor', fillColor)
    if stacksMgr:getShowIconsState() then
        print(self.focus, 'imageAlpha:', imageAlpha)
        setIcon('imageAlpha', imageAlpha)
    end
end -- }}}

function Window:iconFromAppName() -- {{{
    appBundle = hs.appfinder.appFromName(self.app):bundleID()
    return hs.image.imageFromAppBundle(appBundle)
end -- }}}

function Window:deleteIndicator() -- {{{
    if self.indicator then
        self.indicator:delete(self.fadeDuration)
    end
end -- }}}

return Window
