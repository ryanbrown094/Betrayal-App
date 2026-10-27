-- The simulator's second display, for the CI's AirPlay run (.github/workflows/ios.yml): its menu's External Displays,
-- at 1080p or else the first size offered. Says what the menu had, and what it chose.
--   osascript ci/external.applescript
set AppleScript's text item delimiters to ", "
tell application "Simulator" to activate
delay 3
tell application "System Events"
	tell process "Simulator"
		set ext to missing value
		repeat with top in {"I/O", "Hardware"}
			if exists menu bar item (top as text) of menu bar 1 then
				set m to menu 1 of menu bar item (top as text) of menu bar 1
				log (top as text) & ": " & (name of every menu item of m as text)
				repeat with i in (every menu item of m)
					if (name of i as text) starts with "External" then set ext to menu 1 of i
				end repeat
			end if
		end repeat
		if ext is missing value then return "no External Displays menu"
		set sizes to every menu item of ext
		log "External Displays: " & (name of every menu item of ext as text)
		repeat with i in sizes
			if (name of i as text) contains "1920" then
				click i
				return "chose " & (name of i as text)
			end if
		end repeat
		click item 2 of sizes
		return "chose " & (name of item 2 of sizes as text)
	end tell
end tell
