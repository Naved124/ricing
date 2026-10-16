-- Entry point. Three layers, loaded in order:
--   base.lua    keybinds, input, layout, window tags   (never changes)
--   rice        ~/.config/rices/current/build/hypr.lua  (borders, blur, animations)
--   local.lua   this machine: monitors, keyboard layout (optional, not in the repo)
-- `rice <name>` swaps the `current` symlink and runs `hyprctl reload`.

require("base")

local rice = os.getenv("HOME") .. "/.config/rices/current/build/hypr"
local ok, err = pcall(require, rice)
if not ok then
    print("rice: no visual layer loaded (" .. tostring(err) .. "); run `rice session`")
end

pcall(require, "local")
