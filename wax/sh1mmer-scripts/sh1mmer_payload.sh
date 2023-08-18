source /usr/sbin/sh1mmer_gui.sh
source /usr/sbin/sh1mmer_optionsSelector.sh
shopt -s nullglob

showbg terminalGeneric.png

mapname() {
	case $1 in # you can't use return because bash sux
	'/usr/local/payloads/wifi.sh') printf 'Connect to wifi' ;;
	'/usr/local/payloads/autoupdate.sh') printf 'Fetch updated payloads' ;;
	'/usr/local/payloads/stopupdates.sh') printf 'Disable updates' ;;
	'/usr/local/payloads/weston.sh') printf 'Launch the weston Desktop Environment' ;;
	'/usr/local/payloads/movie.sh') printf "Cinematic masterpiece" ;;
	'/usr/local/payloads/mrchromebox.sh') printf "MrChromebox firmware-util.sh" ;;
	'/usr/local/payloads/caliginosity.sh') printf "Revert all changes made by sh1mmer (reenroll + more)" ;;
	'/usr/local/payloads/defog.sh') printf "Defog" ;;

	*) printf $1 ;;
	esac
}

selectorLoop() {
	selected=0
	while true; do
		idx=0
		for opt; do
			movecursor_generic $idx
			if [ $idx -eq $selected ]; then
				echo -n "--> $(mapname $opt)"
			else
				echo -n "    $(mapname $opt)"
			fi
			((idx++))
		done
		input=$(readinput)
		case $input in
		'kB') exit ;;
		'kE') return $selected ;;
		'kU')
			((selected--))
			if [ $selected -lt 0 ]; then selected=0; fi
			;;
		'kD')
			((selected++))
			if [ $selected -ge $# ]; then selected=$(($# - 1)); fi
			;;
		esac
	done
}
while true; do
	options=(/usr/local/payloads/*.sh)
	selectorLoop "${options[@]}"
	sel="$?"
	showbg terminalGeneric.png
	movecursor_generic 0
	bash "${options[$sel]}"
	sleep 2
	showbg terminalGeneric.png
done
