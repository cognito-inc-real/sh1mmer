#!/bin/bash

/usr/share/vboot/bin/set_gbb_flags.sh 0x8090
/usr/share/vboot/bin/set_gbb_flags 0xA9
flashrom --wp-disable
sudo vpd -i RW_VPD -s check_enrollment=0
sudo vpd -i RW_VPD -s block_devmode=0
sudo crossystem block_devmode=0