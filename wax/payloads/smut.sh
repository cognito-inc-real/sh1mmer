source /usr/local/payloads/gui_lib.sh
allowtext
clear

get_largest_nvme_namespace() {
    # this function doesn't exist if the version is old enough, so we redefine it
    local largest size tmp_size dev
    size=0
    dev=$(basename "$1")

    for nvme in /sys/block/"${dev%n*}"*; do
        tmp_size=$(cat "${nvme}"/size)
        if [ "${tmp_size}" -gt "${size}" ]; then
            largest="${nvme##*/}"
            size="${tmp_size}"
        fi
    done
    echo "${largest}"
}

get_booted_kernnum() {
    if (($(cgpt show -n "$dst" -i 2 -P) > \$(cgpt show -n "$dst" -i 4 -P))); then
        echo -n 2
    else
        echo -n 4
    fi
}

opposite_num() {
    if [ "$1" == "2" ]; then
        echo -n 4
    elif [ "$1" == "4" ]; then
        echo -n 2
    elif [ "$1" == "3" ]; then
        echo -n 5
    elif [ "$1" == "5" ]; then
        echo -n 3
    else
        return 1
    fi
}

if crossystem wp_sw?1; then
    echo "WP not disabled - try on v105 with no battery"
    return
fi
echo "Defogging..."
vpd -i RW_VPD -s check_enrollment=0
vpd -i RW_VPD -s block_devmode=0
crossystem block_devmode=0
res=$(cryptohome --action=get_firmware_management_parameters 2>&1)
if [ $? -eq 0 ] && [[ ! $(echo $res | grep "Unknown action") ]]; then
    tpm_manager_client take_ownership
    # sleeps no longer needed
    cryptohome --action=remove_firmware_management_parameters
fi
/usr/share/vboot/bin/set_gbb_flags.sh 0x8090
crossystem block_devmode=0
vpd -i RW_VPD block_devmode=0


echo "Probing for USB drive..."
sync
fdisk -l

echo "Enter your USB drive's device name from above (e.g. sda):"
read -p " > " usbdev

echo "Mounting USB drive..."
mkdir -p /mnt/usb
mount /dev/$usbdev /mnt/usb
$files=$(ls /mnt/usb/*.bin)

echo "Found files:"
echo $files

sleep 3

clear

# ascii art logo
echo "  _________.__    ____                                  \n /   _____/\|  \|__/_   \| _____   _____   ___________     \n \\_____  \\ \|  \|  \\\|   \|/     \\ /     \\_/ __ \\_  __ \\    \n /        \\\|   Y  \\   \|  Y Y  \\  Y Y  \\  ___/\|  \| \\/    \n/_______  /\|___\|  /___\|__\|_\|  /__\|_\|  /\\___  \>__\|       \n        \\/      \\/          \\/      \\/     \\/           \n   _____        .__   __  ._____.                  __   \n  /     \\  __ __\|  \|_/  \|_\|__\\_ \|__   ____   _____/  \|_ \n /  \\ /  \\\|  \|  \\  \|\\   __\\  \|\| __ \\ /  _ \\ /  _ \\   __\\\n/    Y    \\  \|  /  \|_\|  \| \|  \|\| \\_\\ \(  \<_\> \|  \<_\> \)  \|  \n\\____\|__  /____/\|____/__\| \|__\|\|___  /\\____/ \\____/\|__\|  \n        \\/                        \\/                    \n ____ ______________.__.__  .__  __                     \n\|    \|   \\__    ___/\|__\|  \| \|__\|/  \|_ ___.__.           \n\|    \|   / \|    \|   \|  \|  \| \|  \\   __\<   \|  \|           \n\|    \|  /  \|    \|   \|  \|  \|_\|  \|\|  \|  \\___  \|           \n\|______/   \|____\|   \|__\|____/__\|\|__\|  / ____\|           \n                                      \\/           \n                   or\n              S   M   U   T"

cat << EOF


Select a utility to run:
 1) Install fakemurk/murkmod recovery image to unused partition
 2) Overwrite all partitions and flash recovery image
 3) Boot into recovery image/shim
 4) Exit

EOF

read -p " > " choice

choose_image() {
    read -p " > " image
    echo "$image"
}

install_fakemurk() {
    echo "Choose a recovery image:"
    echo $files
    $image=$(choose_image)
    if [ -f "/mnt/usb/$image" ]; then
        echo "Finding target partitions..."
        local dst=/dev/$(get_largest_nvme_namespace)
        local tgt_kern=$(opposite_num $(get_booted_kernnum))
        local tgt_root=$(( $tgt_kern + 1 ))
        echo "Targeting $tgt_kern and $tgt_root"
        local loop=$(losetup -f | tr -d '\r')
        losetup -P "$loop" "/mnt/usb/$image"
        printf "Overwriting partitions in 3 (this is your last chance to cancel)..."
        sleep 1
        printf "2..."
        sleep 1
        echo "1..."
        sleep 1
        echo "Bomb has been planted! Overwriting ChromeOS..."
        echo "Installing kernel patch to ${kerndev}..."
        dd if="${loop}p4" of="$kerndev" status=progress
        echo "Installing root patch to ${rootdev}..."
        dd if="${loop}p3" of="$rootdev" status=progress
        echo "Setting kernel priority..."
        cgpt add "$dst" -i 4 -P 0
        cgpt add "$dst" -i 2 -P 0
        cgpt add "$dst" -i "$tgt_kern" -P 1
        echo "Double-checking defog..."
        /usr/share/vboot/bin/set_gbb_flags.sh 0x8090
        crossystem block_devmode=0
        vpd -i RW_VPD block_devmode=0
        vpd -i RW_VPD -s check_enrollment=1 # for fakemurk this stays on
        echo "Done!"
        read "Press enter to continue..."
    else
        echo "File not found!"
        read "Press enter to continue..."
    fi
}

reco_from_bin() {
    echo "Choose a recovery image:"
    echo $files
    $image=$(choose_image)
    if [ -f "/mnt/usb/$image" ]; then
        echo "Finding target partitions..."
        local dst=/dev/$(get_largest_nvme_namespace)
        local tgt_kern=$(opposite_num $(get_booted_kernnum))
        local tgt_root=$(( $tgt_kern + 1 ))
        local tgt_kern2=$(get_booted_kernnum)
        local tgt_root2=$(( $tgt_kern2 + 1 ))
        echo "Targeting $tgt_kern and $tgt_root"
        local loop=$(losetup -f | tr -d '\r')
        losetup -P "$loop" "/mnt/usb/$image"
        printf "Overwriting partitions in 3 (this is your last chance to cancel)..."
        sleep 1
        printf "2..."
        sleep 1
        echo "1..."
        sleep 1
        echo "Bomb has been planted! Overwriting ChromeOS..."
        echo "Installing kernel patch to ${kerndev}..."
        dd if="${loop}p4" of="$kerndev" status=progress
        echo "Installing root patch to ${rootdev}..."
        dd if="${loop}p3" of="$rootdev" status=progress
        echo "Installing kernel patch to ${kerndev2}..."
        dd if="${loop}p4" of="$kerndev2" status=progress
        echo "Installing root patch to ${rootdev2}..."
        dd if="${loop}p3" of="$rootdev2" status=progress
        echo "Setting kernel priority..."
        cgpt add "$dst" -i 4 -P 0
        cgpt add "$dst" -i 2 -P 0
        cgpt add "$dst" -i "$tgt_kern" -P 1
        echo "Double-checking defog..."
        /usr/share/vboot/bin/set_gbb_flags.sh 0x8090
        crossystem block_devmode=0
        vpd -i RW_VPD block_devmode=0
        vpd -i RW_VPD -s check_enrollment=0 # stays off here
        echo "Done!"
        read "Press enter to continue..."
    else
        echo "File not found!"
        read "Press enter to continue..."
    fi
}

boot_reco() {
    echo "Not implemented yet!"
    read "Press enter to continue..."
}

case $choice in
    1)
        install_fakemurk
        ;;
    2)
        reco_from_bin
        ;;
    3)
        boot_reco
        ;;
    4)
        echo "Bye!"
        ;;
    *)
        echo "Invalid choice!"
        ;;
esac

disallowtext