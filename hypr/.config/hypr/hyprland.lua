-- Entry point. Three layers, loaded in order:
--   base.lua    keybinds, input, layout, window tags   (never changes)
--   rice        ~/.local/share/rice/active/hypr.lua  (borders, blur, animations)
--   local.lua   this machine: monitors, keyboard layout (optional, not in the repo)
-- `active` is the active rice's build in the active mode (light or dark);
-- `rice <name>` swaps the `current` symlink under it and runs `hyprctl reload`.

require("base")

local data = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")
local rice = data .. "/rice/active/hypr"
local ok, err = pcall(require, rice)
if not ok then
    print("rice: no visual layer loaded (" .. tostring(err) .. "); run `rice session`")
end

pcall(require, "local")
