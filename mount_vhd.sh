export VHD="/home/nobody/MiSTer/DOS/Top300DOSGames.vhd"
export MOUNTPOINT="/media/vhd"

sudo guestmount -a ${VHD} -m /dev/sda2 -o allow_other --rw ${MOUNTPOINT}
echo "Mounted "$VHD" at "$MOUNTPOINT":"
ls /media/vhd
