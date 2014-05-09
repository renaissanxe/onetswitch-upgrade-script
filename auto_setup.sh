# *************************************************************** #
#   File Name: auto_upgrade.sh                                    #
#   Version: 1.0                                                  #
#   Date Apr 18, 2014                                             #
#   Author: Jamie Yang                                            #
#   Description:    This an auto reconfigure file for XJTU SDN    #
#                   rack Demo.                                    #
#                   Input should be number or string.             #
#                   --all means upgrade all racks                 #
#                   --select M N means upgrade selected board     #
#                       M=[1,2], N=[0,9]                          #
#                   --sd, --net means upgrade via which media     #
# *************************************************************** #
#!/bin/bash

DEFAULT=all

function prepare_init_file()
{
#   OLD_TEXT=$1
#   NEW_TEXT=$2
    XARG=$1$2
    sed 's/XARG/'$XARG'/' init_sh_template.txt > bootfs/init.sh
}

function upgrade_net()
{
    echo "Upgrade Stack" $1", Number" $2 "via Net"
    if [ -z "$3" ]
    then
	target_ip=10.0.0.$1$2
    else
	target_ip=$3
    fi

    expect -c "set timeout 30;
	spawn ssh root@$target_ip /bin/rm -rf /root/*;
        expect {
            \*yes/no\* {send -- yes\r;exp_continue;}
            \*password:\* {send -- root\r;exp_continue;}
	    eeof    {exit 0;}
        }

        spawn scp bootfs/boot.bin root@$target_ip:/mnt;
        expect {
            \*yes/no\* {send -- yes\r;exp_continue;}
            \*password:\* {send -- root\r;exp_continue;}
            eeof {exit 0;}
        }

	spawn scp bootfs/uImage root@$target_ip:/mnt;
        expect {
            *yes/no* {send -- yes\r;exp_continue;}
            *password:* {send -- root\r;exp_continue;}
            eeof    {exit 0;}
        }

	spawn scp bootfs/devicetree.dtb root@$target_ip:/mnt;
        expect {
            *yes/no* {send -- yes\r;exp_continue;}
            *password:* {send -- root\r;exp_continue;}
            eeof    {exit 0;}
        }

	spawn scp bootfs/init.sh root@$target_ip:/mnt;
        expect {
            *yes/no* {send -- yes\r;exp_continue;}
            *password:* {send -- root\r;exp_continue;}
            eeof    {exit 0;}
        }

	spawn scp -r rootfs/root/ofsoftswitch13hwt root@$target_ip:/root/.;
        expect {
            *yes/no* {send -- yes\r;exp_continue;}
            *password:* {send -- root\r;exp_continue;}
            eeof    {exit 0;}
        }";
}

function upgrade_sd()
{
    echo "Info: Insert SD card and press any key to continue ..."
    read -n 1

    TARGET_DEV="/dev/mmcblk0"

    if ! [ -b /dev/mmcblk0 ]
    then
        echo "Error: SD card not found, insert and run again"
        exit 1
    fi

    if ! [ -b /dev/mmcblk0p2 -a -b /dev/mmcblk0p1 ]
    then
        echo "SD not format ... Formating..."
        parted -s $TARGET_DEV mkpart primary fat32 0 1024
        parted -s $TARGET_DEV mkpart primary ext2 1024 3900
	mkfs.fat $TARGET_DEV"p1" -n bootfs
	mkfs.ext4 $TARGET_DEV"p2" -L rootfs
    fi

    TARGET_PART1=$TARGET_DEV"p1"
    TARGET_PART2=$TARGET_DEV"p2"
    mount $TARGET_PART1 bootmnt/
    mount $TARGET_PART2 rootmnt/
    rsync -a bootfs/ bootmnt/
    rsync -a rootfs/ rootmnt/
    umount -A $TARGET_PART1
    umount -A $TARGET_PART2

    echo "Info: Now please extract SD card."
    sleep 10
}


# test if the first string right
if [ -z "$1" ]
then
    echo "Error: need and input. Use -h for help"
fi

if [ "$1" == "-h" ]
then
    echo "Upgrade the SDN rack demo from XJTU."
    echo "--all : means upgrade all"
    echo "--select M N : means upgrade the board at rack M, board N"
    echo "example: --sd --select 1 2"
    echo "example: --net --select 1 2"
    echo "example: --net --select 1 2 --ip 10.0.0.10"
    echo " "
    exit 0
fi

write_target="DEFAULT"
if [ "$1" == "--sd" ]
then
    write_target="SD"
    upgrade_function=upgrade_sd
elif [ "$1" == "--net" ]
then
    write_target="NET"
    upgrade_function=upgrade_net
else
    echo "Error arguement 1, should be --sd or --net"
    exit -1
fi

write_range="DEFAULT"
if [ "$2" == "--all" ]
then
    write_range="ALL"
elif [ "$2" == "--select" ]
then
    write_range="SELECT"
    if test -n $3
    then
        write_rack=$3
    else
        echo "Error: Rack number required"
        exit -1
    fi
    if test -n $4
    then
        write_num=$4
    else
        echo "Error: Board number required"
        exit -1
    fi
else
    echo "Error argument 2, should be --all or --select"
    exit -1
fi

if [ $write_range == "ALL" ]
then
    for M in 1 2
    do
        for N in 0 1 2 3 4 5 6 7 8 9
        do
            echo "Info: Target board index: rack = "$M", number = "$N
            echo "Process: Target board upgrade start..."
            prepare_init_file $M $N;
            $upgrade_function $M $N;
            echo "Process: Target board upgrade done!"
        done
    done
elif [ $write_range == "SELECT" ]
then
    echo "Info: Target board index: rack = "$write_rack", number = "$write_num
    echo "Process: Target board upgrade start..."
    prepare_init_file $write_rack $write_num;
    if [ -z "$5" ]
    then
    	$upgrade_function $write_rack $write_num;
    else
	if [ -z "$6" ]
	then
	    echo "Error need an ip address"
	    exit 1
	fi
	if [ "$5" == "--ip" ]
	then
	    target_ip=$6
	    $upgrade_function $write_rack $write_num $target_ip;
	else
	    echo "Error: should be --ip xxx.xxx.xxx.xxx"
	    exit 1
	fi
    fi
    echo "Process: Target board upgrade done!"
fi

echo "Info: Upgrade finished. Please reboot the whole system."
