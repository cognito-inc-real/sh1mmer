 #!/bin/bash
if crossystem wp_sw?1; then
    echo "WP not disabled - try on v105 with no battery"
    return
fi
/usr/share/vboot/bin/set_gbb_flags.sh 0x8090
crossystem block_devmode=0
vpd -i RW_VPD block_devmode=0
echo "GBB flags set. Devmode should now be unblocked, you're good to proceed"
read -p "Press enter to continue" 
