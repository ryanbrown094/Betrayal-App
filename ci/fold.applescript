-- The iPhone Duo simulator, opened (unfolded) from the Simulator app's own menus, for the CI (.github/workflows/ios.yml):
-- logs every menu and submenu item it finds, then clicks the first whose name says it opens or unfolds the device.
--   osascript ci/fold.applescript
set AppleScript's text item delimiters to ", "
tell application "Simulator" to activate
delay 3
tell application "System Events"
	tell process "Simulator"
		set target to missing value
		repeat with top in (every menu bar item of menu bar 1)
			set topName to name of top as text
			try
				set m to menu 1 of top
				log topName & ": " & (name of every menu item of m as text)
				repeat with i in (every menu item of m)
					set n to name of i as text
					if target is missing value and (n contains "Unfold" or n is "Open" or n contains "Open Device") then set target to i
					try
						set sm to menu 1 of i
						log "  " & n & " > " & (name of every menu item of sm as text)
						repeat with j in (every menu item of sm)
							set jn to name of j as text
							if target is missing value and (jn contains "Unfold" or jn is "Open" or jn contains "Opened") then set target to j
						end repeat
					end try
				end repeat
			end try
		end repeat
		if target is missing value then return "nothing that opens the device"
		set picked to name of target as text
		click target
		return "clicked " & picked
	end tell
end tell
