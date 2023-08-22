#!/bin/bash

source /usr/sbin/sh1mmer_gui.sh

cleanup

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
    read "Press enter to continue"
    exit 0
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

clear

echo "Probing for USB drive..."
sync
fdisk -l

echo "Enter your USB drive's device name from above (e.g. /dev/sdb):"
read -p " > " usbdev

echo "Mounting USB drive..."
mkdir -p /mnt/usb
mount "$usbdev" /mnt/usb
$files=$(ls /mnt/usb/*.bin)

echo "Found files:"
echo $files

sleep 3

clear

# ascii art logo

cat << EOF
  _________.__    ____                                  
 /   _____/|  |__/_   | _____   _____   ___________     
 \_____  \ |  |  \|   |/     \ /     \_/ __ \_  __ \    
 /        \|   Y  \   |  Y Y  \  Y Y  \  ___/|  | \/    
/_______  /|___|  /___|__|_|  /__|_|  /\___  >__|       
        \/      \/          \/      \/     \/           
   _____        .__   __  ._____.                  __   
  /     \  __ __|  |_/  |_|__\_ |__   ____   _____/  |_ 
 /  \ /  \|  |  \  |\   __\  || __ \ /  _ \ /  _ \   __\
/    Y    \  |  /  |_|  | |  || \_\ (  <_> |  <_> )  |  
\____|__  /____/|____/__| |__||___  /\____/ \____/|__|  
        \/                        \/                    
     ____ ______________.__.__  .__  __                     
    |    |   \__    ___/|__|  | |__|/  |_ ___.__.           
    |    |   / |    |   |  |  | |  \   __<   |  |           
    |    |  /  |    |   |  |  |_|  ||  |  \___  |           
    |______/   |____|   |__|____/__||__|  / ____|           
                                          \/            
                       or
                   SMUT v1.2

Select a utility to run:
 1) Install fakemurk/murkmod recovery image to unused partition
 2) Overwrite all partitions and flash recovery image
 3) Boot into recovery image/shim
 4) Exit

EOF

read -p " > " choice

install_fakemurk() {
    echo "Choose a recovery image:"
    echo $files
    read -p " > " image
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

setup
