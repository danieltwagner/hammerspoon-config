-- Keeps windows in place

local obj={}
obj.__index = obj

-- Metadata
obj.name = "Stay"
obj.version = "0.1"
obj.author = "Daniel Wagner"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.menu_bar_item = nil
obj.window_config = {}
CONFIG_VERSION = 1
-- The config schema is a table:
-- { 
--     string_describing_screen_arrangement = {
--         app_bundle_id = {
--             window_title = {
--                 x = 234,
--                 y = 345,
--                 w = 456,
--                 h = 567,
--             },
--             another_window_title = { ... },
--         },
--         another_app_bundle_id = { ... }
--     },
--     another_screen_config = { ... }
-- }

--- Stay.config_path
--- Variable
--- Path at which window layouts are stored. Defaults to `~/.hs_stay.plist`
obj.config_path = "~/.hs_stay.plist"

--- Stay.show_in_menubar
--- Variable
--- Whether to show a menubar item to save/restore window positions. Defaults to `true`
obj.show_in_menubar = true

--- Stay.menubar_title
--- Variable
--- String to show in the menubar if `Stay.show_in_menubar` is `true`. Defaults to `"\u{1F5a5}"`, which is the [Unicode desktop computer character](https://codepoints.net/U+1F5A5)
obj.menubar_title = "\u{1F5a5}"

--- Stay.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('Stay')

--- Stay.apps_blacklist
--- Variable
--- Windows for App bundle IDs listed here will never be recorded.
obj.apps_blacklist = {}

--- Stay.apps_exact_match
--- Variable
--- Windows for App bundle IDs listed here will need to match exactly (not fuzzily).
obj.apps_exact_match = {}

--- Stay.move_non_matching_windows
--- Variable
--- Controls whether to move windows that don't match previously recorded windows for the same app.
obj.move_non_matching_windows = false

--- Stay.exact_matcher()
--- Method
--- A frame_picker that matches window keys. Windows that don't match a previously recorded title exactly will not be moved.
function obj:exact_matcher(window, app, key, app_entries)
    if app_entries[key] ~= nil then
        frame = app_entries[key]
        return hs.geometry.rect(frame.x, frame.y, frame.w, frame.h)
    end

    return nil
end

--- Stay.fuzzy_matcher()
--- Method
--- A frame_picker that fuzzily matches window keys. Windows for app bundle IDs listed in Stay.apps_exact_match will need to match exactly. If no match is found, Stay.move_non_matching_windows can be set to true to pick the first frame previously recorded for this app.
function obj:fuzzy_matcher(window, app, key, app_entries)

    frame = obj:exact_matcher(window, app, key, app_entries)
    if frame or self.apps_exact_match[app] then
        -- There was either an exact match or no match but we're not allowed to fuzzy-match this app
        return frame
    end

    -- now try to find a fuzzy match
    self.logger.df("Fuzzy matching \"%s\"", key)
    highest_score = 0
    for k, f in pairs(app_entries) do
        this_score = _score_match(k, key)
        if this_score > highest_score then
            self.logger.df("Fuzzy match %s (score %d) > %d", k, this_score, highest_score)
            highest_score = this_score
            frame = f
        end
    end

    if frame == nil then
        -- we found no matching frame. Should we give up, or should we pick a random previous frame?
        if self.move_non_matching_windows then
            for _, f in pairs(app_entries) do
                frame = f
                break
            end
        else
            return nil
        end
    end

    return hs.geometry.rect(frame.x, frame.y, frame.w, frame.h)
end

--- Stay.frame_picker
--- Variable
--- Pointer to a function that returns a frame for a window given stored windows for the same app and screen configuration. Defaults to Stay.fuzzy_matcher. Set to Stay.exact_matcher to match exact window titles only. Override to do custom handling of window frames. Signature is (window, app, key, table_of_stored_windows_to_frames) -> hs.geometry.rect, or nil.
obj.frame_picker = obj.fuzzy_matcher

function _score_match(previous, current)
    score = 0

    -- we could be smarter and try to weight contiguous sections more strongly or so...
    current_parts = current:split()
    for _, p in ipairs(current_parts) do
        if string.find(previous, p, 1, true) then
            score = score + 1
        end
    end

    return score
end

function string:split(sep)
    sep = sep or " "
    fields = {}
    pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

--- Stay:clear_all()
--- Method
--- Clears all window positions for the current layout
function obj:clear_all()
    screens_string = _get_current_screen_config()
    self.window_config[screens_string] = nil
    self.logger.df("Finished clearing all window positions for screen configuration \"%s\".", screens_string)
end

--- Stay:save_all()
--- Method
--- Saves all window positions for the current layout
function obj:save_all()
    screens_string = _get_current_screen_config()
    if self.window_config[screens_string] == nil then
        self.window_config[screens_string] = {}
    end
    self.logger.df("Collecting all window positions for screen configuration \"%s\"...", screens_string)

    windows = hs.window.visibleWindows()
    for i = 1, #windows do
        self:save_window_for_screen_config(windows[i], screens_string)
    end

    self.logger.df("Finished collecting all window positions for screen configuration \"%s\".", screens_string)
    self:write_config()
end

--- Stay:save_window()
--- Method
--- Save a single window's position for the current layout
function obj:save_window(window)
    screens_string = _get_current_screen_config()
    if self.window_config[screens_string] == nil then
        self.window_config[screens_string] = {}
    end
    self.save_window_for_screen_config(window, screens_string)
    self:write_config()
end

--- Stay:restore_all()
--- Method
--- Restore all window positions
function obj:restore_all(allow_similar_config)
    screens_string = _get_current_screen_config()
    if self.window_config[screens_string] == nil then
        -- turns out similar layouts don't work as offsets are wrong
        if allow_similar_config and false then
            self.logger.df("Checking for similar layout...")
            screens_string = _find_similar_layout(self, screens_string)
            if screens_string == nil then
                return
            end
        else
            self.logger.df("Can't restore windows as there is no config for layout \"%s\".", screens_string)
            return
        end
    end

    self.logger.df("Restoring all window positions for screen configuration \"%s\"...", screens_string)

    windows = hs.window.visibleWindows()
    for i = 1, #windows do
        self:restore_window_for_screen_config(windows[i], screens_string)
    end

    self.logger.df("Finished restoring all window positions for screen configuration \"%s\".", screens_string)
end

--- Stay:restore_window()
--- Method
--- Restore a single window's position
function obj:restore_window(window)
    screens_string = _get_current_screen_config()
    if self.window_config[screens_string] == nil then
        self.logger.df("Can't restore window as there is no config for layout \"%s\".", screens_string)
        return
    end
    self.restore_window_for_screen_config(window, screens_string)
end



--- Stay:load_config()
--- Method
--- Load window positions from disk. This happens automatically on start
function obj:load_config()
    from_disk = hs.plist.read(self.config_path)
    if from_disk then
        if from_disk.config_version == CONFIG_VERSION then
            self.window_config = from_disk.window_config
            self.logger.df("Loaded window configuration from %s: %s", self.config_path, _dump(self.window_config))
        else
            self.logger.df("Config version %d didn't match expected version %d", from_disk.config_version, CONFIG_VERSION)
        end
    else
        self.logger.df("Found no prior window configuration.")
    end
end

--- Stay:write_config()
--- Method
--- Write window positions to disk
function obj:write_config()
    to_write = {
        config_version = CONFIG_VERSION,
        window_config = self.window_config,
    }
    hs.plist.write(self.config_path, to_write)
    self.logger.df("Wrote window configuration to %s.", self.config_path)
end

--- Stay:start()
--- Method
--- Start the window collector and load window positions from disk
function obj:start()
    if self.menu_bar_item then self:stop() end
    if self.show_in_menubar then
        self.menu_bar_item = hs.menubar.new()
        :setTitle(obj.menubar_title)
        :setMenu({
            {title = "Save all window positions for this layout", fn = hs.fnutils.partial(self.save_all, self)},
            {title = "Clear window positions for this layout", fn = hs.fnutils.partial(self.clear_all, self)},
            {title = "Restore all window positions", fn = hs.fnutils.partial(self.restore_all, self, true)},
        })
    end

    self:load_config()

    return self
end

--- Stay:stop()
--- Method
--- Stop the window collector
function obj:stop()
    if self.menu_bar_item then self.menu_bar_item:delete() end
    self.menu_bar_item = nil

    return self
end

function obj:save_window_for_screen_config(window, screens_string)
    app, key = _key_for_window(window)

    screen_config = self.window_config[screens_string]
    if screen_config[app] == nil then
        screen_config[app] = {}
    end
    screen_config[app][key] = _entry_for_window(window)

    self.logger.df("Saved %s = %s", key, _dump(self.window_config[screens_string][app][key]))
end

function obj:restore_window_for_screen_config(window, screens_string)
    screen_config = self.window_config[screens_string]

    app, key = _key_for_window(window)
    app_entries = screen_config[app]
    if app_entries == nil then
        self.logger.df("Found no configuration for app '%s'", app)
        return
    end

    frame = self:frame_picker(window, app, key, app_entries)

    if frame and window:frame() ~= frame then
        self.logger.df("Moving '%s %s' from %s to %s", app, key, _dump(window:frame()), _dump(frame))
        window:move(frame)
    end
end

function _key_for_window(window)
    return window:application():bundleID(), window:title()
end

function _entry_for_window(window)
    f = window:frame()
    return {
        x = f.x,
        y = f.y,
        w = f.w,
        h = f.h,
    }
end

function _get_current_screen_config()
    -- returns a string that describes the connected screens and their relative positions (x,y,w,h):
    -- "0.0,0.0,1920.0,1080.0 1920.0,0.0,1680.0,1050.0" describes two screens (1920x1080) (1680x1050)
    -- the entries are ordered lexicographically, which ought to do the right thing.
    strings = {}
    for s, pos in pairs(hs.screen.screenPositions()) do
        frame = s:fullFrame()
        table.insert(strings, frame.x .. "," .. frame.y .. "," .. frame.w .. "," .. frame.h .. " ")
    end

    result = ""
    table.sort(strings)
    for _, scr in ipairs(strings) do
        result = result .. scr
    end

    return result
end

function _decode_screens_string(screens_string)
    screens = {}
    for i, s in ipairs(screens_string:split(" ")) do
        rect = s:split(",")
        table.insert(screens, {x = tonumber(rect[1]), y = tonumber(rect[2]), w = tonumber(rect[3]), h = tonumber(rect[4])})
    end
    return screens
end

function _is_similar_layout(a, b)
    if #a ~= #b then
        return false
    end

    for i, b_screen in ipairs(b) do
        a_screen = a[i]
        -- we're comparing width + height only
        if a_screen.w ~= b_screen.w or a_screen.h ~= b_screen.h then
            return false
        end
    end
    return true
end

function _find_similar_layout(self, screens_string)
    -- Find layouts with identical screen sizes
    curr_layout = _decode_screens_string(screens_string)
    self.logger.df("current layout is \"%s\"", screens_string)
    candidates = {}
    for k, _ in pairs(self.window_config) do
        candidate_layout = _decode_screens_string(k)
        if _is_similar_layout(candidate_layout, curr_layout) then
            table.insert(candidates, k)
        end
    end

    if #candidates == 0 then
        self.logger.df("Found no similar layout.")
        return nil
    elseif #candidates > 1 then
        self.logger.df("Found more than one similar layout: %s", _dump(candidates))
        return nil
    end

    self.logger.df("Found one similar layout: \"%s\"", candidates[1])
    return candidates[1]
end

function _dump(o)
   if type(o) == 'table' then
      local s = ''
      for k,v in pairs(o) do
         -- if type(k) ~= 'number' then k = '"' .. k .. '"' end
         if #s > 0 then s = s .. ", " end
         s = s .. '"' .. k  .. '" : ' .. _dump(v)
      end
      return '{' .. s .. '} '
   elseif type(o) == 'string' then
      return '"' .. tostring(o) .. '"'
   else
      return tostring(o)
   end
end

return obj
