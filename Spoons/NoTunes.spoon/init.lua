--- === NoTunes ===
---
--- Keeps Apple Music (and iTunes) from launching, like https://github.com/tombonez/noTunes
---
--- Whenever a blocked app launches (e.g. because the play key was pressed or
--- headphones were connected), it is force-terminated right away. Optionally,
--- a replacement app (or URL) is opened instead.

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "NoTunes"
obj.version = "0.1"
obj.author = "Daniel Wagner"
obj.homepage = "https://github.com/tombonez/noTunes"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- NoTunes.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('NoTunes')

--- NoTunes.blocked_bundle_ids
--- Variable
--- Bundle IDs of apps that are terminated as soon as they launch. Defaults to Apple Music and iTunes.
obj.blocked_bundle_ids = { "com.apple.Music", "com.apple.iTunes" }

--- NoTunes.replacement
--- Variable
--- Optional app to open whenever a blocked app was terminated: an app name (e.g. `"Spotify"`), the full path to an `.app`, or a URL (e.g. `"https://music.youtube.com"`). Defaults to `nil` (open nothing).
obj.replacement = nil

obj.watcher = nil
obj.last_replacement_launch = 0

local function is_blocked(self, bundle_id)
    return bundle_id ~= nil and hs.fnutils.contains(self.blocked_bundle_ids, bundle_id)
end

function obj:launch_replacement()
    if not self.replacement then return end

    -- We see both the "launching" and the "launched" event for a single launch,
    -- so make sure we only open the replacement once.
    local now = hs.timer.secondsSinceEpoch()
    if now - self.last_replacement_launch < 2 then return end
    self.last_replacement_launch = now

    self.logger.df("Opening replacement %s", self.replacement)
    if self.replacement:find("://", 1, true) then
        hs.urlevent.openURL(self.replacement)
    else
        hs.application.launchOrFocus(self.replacement)
    end
end

function obj:terminate(app)
    self.logger.df("Terminating %s (pid %s)", app:bundleID(), app:pid())
    app:kill9()
end

function obj:handle_app_event(_, event, app)
    if event ~= hs.application.watcher.launching and event ~= hs.application.watcher.launched then
        return
    end
    if app == nil or not is_blocked(self, app:bundleID()) then return end

    self:terminate(app)
    self:launch_replacement()
end

--- NoTunes:start()
--- Method
--- Terminates any blocked apps that are already running and starts watching for new launches
function obj:start()
    if self.watcher then self:stop() end

    for _, bundle_id in ipairs(self.blocked_bundle_ids) do
        for _, app in ipairs(hs.application.applicationsForBundleID(bundle_id)) do
            self:terminate(app)
        end
    end

    self.watcher = hs.application.watcher.new(function(name, event, app)
        self:handle_app_event(name, event, app)
    end):start()

    return self
end

--- NoTunes:stop()
--- Method
--- Stops watching for app launches
function obj:stop()
    if self.watcher then self.watcher:stop() end
    self.watcher = nil

    return self
end

return obj
