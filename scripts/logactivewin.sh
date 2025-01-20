#!/bin/bash
# logactivewin.sh for https://github.com/Naereen/uLogMe/
# MIT Licensed, https://lbesson.mit-license.org/
#

# Use https://bitbucket.org/lbesson/bin/src/master/.color.sh to add colors in Bash scripts
[ -f color.sh ] && . color.sh

# For the language to be in English for this script
# XXX This is not very pretty but it works: the sleep detection and other code look for patterns in the command line output of some commands
readonly LANGUAGE=en
readonly LANG=en_US.utf8

# logs the active window titles over time. Logs are written
# in ../logs/window_X.txt, where X is unix timestamp of 7am of the
# recording day. The logs are written if a window change event occurs
# (with 2 second frequency check time), or every 10 minutes if
# no changes occur.

waittime="2"   # number of seconds between executions of loop
# maxtime="600"  # if last write happened more than this many seconds ago, write even if no window title changed


type xprintidle 2>/dev/null >/dev/null || echo -e "${red}WARNING: 'xprintidle' not installed${reset}, idle time detection will not be available (screen saver / lock screen detection only) ...\nPlease install 'xprintidle' with the following command:\nsudo apt install xprintidle"

# Get idle time in seconds. If xprintidle is not installed, returns 0.
function get_idle_time() {
    type xprintidle 2>/dev/null >/dev/null && echo $(( $(timeout -s 9 1 xprintidle) / 1000 )) || echo 0
}


mkdir -p ../logs
last_write="0"
lasttitle=""


# First message to inform that the script was started correctly
echo -e "${green}$0 has been started successfully.${reset}"
echo -e "  - It will ${red}constantly${reset} record the title of the active window of your graphical environment."
echo -e "  - It will work in time window of ${red}$waittime${reset} seconds."
echo


# Start the main loop
while true
do
	# By default the title was marked as locked if detection failed, now it's the opposite: it should fix #26
	# FIXED, cf. https://github.com/Naereen/uLogMe/issues/26#issuecomment-430977096
	islocked=false
	# Try to figure out which Desktop Manager is running and set the
	# screensaver commands accordingly.
	if [[ X"$GDMSESSION" == X'xfce' ]]; then
		# Assume XFCE folks use xscreensaver (the default).
		type xscreensaver-command 2>/dev/null >/dev/null
		if [ "X$?" = "X0" ]; then
			islocked=true
			screensaverstate="$(xscreensaver-command -time | cut -f2 -d: | cut -f2-3 -d' ')"
			if [[ "$screensaverstate" =~ "screen non-blanked" ]]; then
				islocked=false
			fi
		fi
	elif [[ X"$GDMSESSION" == X'ubuntu' || X"$GDMSESSION" == X'ubuntu-2d' || X"$GDMSESSION" == X'gnome-shell' || X"$GDMSESSION" == X'gnome-classic' || X"$GDMSESSION" == X'gnome-fallback' ]]; then
		# Assume the GNOME/Ubuntu folks are using gnome-screensaver.
		type gnome-screensaver-command 2>/dev/null >/dev/null
		if [ "X$?" = "X0" ]; then
			screensaverstate="$(gnome-screensaver-command -q 2>/dev/null | grep -o "[^ ]*active")"
			if [[ "$screensaverstate" = active ]]; then
				islocked=true
			fi
		fi
		# XXX We cannot use the xdg-screensaver command
		# type xdg-screensaver 2>/dev/null >/dev/null
		# if [ "X$?" = "X0" ]; then
		# 	screensaverstate="$(xdg-screensaver status 2>/dev/null)"
		# 	if [[ "$screensaverstate" =~ .*disabled.* ]]; then
		# 		islocked=false
		# 	fi
		# fi
	elif [[ X"$GDMSESSION" == X'cinnamon' ]]; then
		type cinnamon-screensaver-command 2>/dev/null >/dev/null
		if [ "X$?" = "X0" ]; then
			screensaverstate="$(cinnamon-screensaver-command -q 2>/dev/null | grep -o "[^ ]*active")"
			if [[ "$screensaverstate" = active ]]; then
				islocked=true
			fi
		fi
	elif [[ X"$XDG_SESSION_DESKTOP" == X'KDE' ]]; then
		type qdbus 2>/dev/null >/dev/null
		if [ "X$?" = "X0" ]; then
			islocked="$(qdbus org.kde.screensaver /ScreenSaver org.freedesktop.ScreenSaver.GetActive)"
		fi
	else
		# If we can't find the screensaver, assume it's missing.
		islocked=false
	fi

	if [ "$islocked" = true ]; then
		curtitle="__LOCKEDSCREEN"  # Special tag
	else
		id="$(xdotool getactivewindow)"
		# curtitle=$(wmctrl -lpG | while read ] && [a; do w=${a[0]}; if (($((16#${w:2}))==id)) ; then echo "${a[@]:8}"; break; fi; done)
		# Quicker and simpler method!
		curtitle="$(xdotool getwindowname "${id}")"
	fi

    # Detect suspend, code from https://github.com/karpathy/ulogme/commit/6a28d34defee65726d55211fe742303737bc757a
    # FIXME this does not work! I should include his changes
    was_awaken=false

    # # First technic
    # suspended_at="$(grep "Freezing user space processes ... *$" /var/log/TOTOkern.log 2>/dev/null | tail -n 1 | awk ' { print $1 " " $2 " " $3 } ' || echo "")"
    # if [ -z "$suspended_at" ]; then
    #     # Second technic
    #     suspended_at="$(grep -E ': (performing suspend|Awake)' /var/log/TOTOpm-suspend.log 2>/dev/null | tail -n 2 | tr '\n' '|' | sed -rn 's/^(.*): performing suspend.*\|.*: Awake.*/\1/p' || echo "")"
    # fi
    # if [ -n "$suspended_at" ]; then
    #     # echo -e "${red}suspended_at = ${suspended_at}${reset} ..."  # DEBUG
    #     if date -d "$suspended_at" +%s 2>/dev/null >/dev/null ; then
    #         suspended_at="$(date -d "$suspended_at" +%s)"
    #         # XXX add 30 seconds, just to be sure that the laptop was indeed asleep at that time
    #         suspended_at=$((suspended_at + 30))
    #         if [ "$suspended_at" -ge "$last_write" ]; then
    #             echo -e "${red}Suspend occured after last event${reset}, '${black}was_awaken${reset}' = true ...${reset}"
    #             was_awaken=true
    #         fi
    #     else
    #         suspended_at="0"
    #         was_awaken=false
    #     fi
    # fi

	# Get suspend information using journalctl
	suspended_at="$(journalctl -kg suspend --since "1 hour ago" | grep "PM: suspend entry" | tail -n 1 | awk '{print $1" "$2" "$3}' || echo "")"
	if [ -n "$suspended_at" ]; then
		if date -d "$suspended_at" +%s 2>/dev/null >/dev/null ; then
			suspended_at="$(date -d "$suspended_at" +%s)"
			# Add 30 seconds buffer time
			suspended_at=$((suspended_at + 30))
			if [ "$suspended_at" -ge "$last_write" ]; then
				echo -e "${red}Suspend occurred after last event${reset}, '${black}was_awaken${reset}' = true ...${reset}"
				was_awaken=true
			fi
		else
			suspended_at="0"
			was_awaken=false
		fi
	fi

	perform_write=false
	# if window title changed, perform write
	if [[ X"$lasttitle" != X"$curtitle" || $was_awaken = true ]]; then
		perform_write=true
	fi

	T="$(date +%s)"

	# if more than some time has elapsed, do a write anyway
	#elapsed_seconds=$(expr $T - $last_write)
	#if [ $elapsed_seconds -ge $maxtime ]; then
	#	perform_write=true
	#fi

	# additional check, do not log private browsing windows (if you have something to hide?)
	# XXX customize here the regexp capturing the titles you don't want to count
	if echo "$curtitle" | grep "\(privée\|InPrivate\|Private\|Incognito\)" 2>/dev/null >/dev/null
	then
		echo -e "${red}Not logged private window title ...${reset}"
		curtitle=""
	fi;

	# log window switch if appropriate
	if [ "$perform_write" = true ] && [ -n "$curtitle"  ]; then
        # Get rewind time, day starts at 7am and ends at 6:59am next day
        rewind7am=$(python3 ./rewind7am.py)
        # One logfile daily
        log_file="../logs/window_${rewind7am}.txt"
        # If computer was just awaken, log suspend event unless it happened before 7am
        if [ $was_awaken = true ] && [ "${suspended_at:-0}" -ge "$rewind7am" ]; then
            echo "$suspended_at __SUSPEND" >> "$log_file"
		fi
		echo "$T $curtitle" >> "$log_file"
		echo -e "Logged ${yellow}window title${reset}: \tat ${magenta}$(date)${reset}, \ttitle '${green}$curtitle${reset}', written to '${black}$log_file${reset}'"
		last_write="$T"
	fi

	lasttitle="$curtitle"  # swap
	sleep "$waittime"  # sleep
done
