#=============================================================================
# Copyright (c) 2019-2024 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#
# Copyright (c) 2009-2012, 2014-2019, The Linux Foundation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of The Linux Foundation nor
#       the names of its contributors may be used to endorse or promote
#       products derived from this software without specific prior written
#       permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NON-INFRINGEMENT ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#=============================================================================

function configure_read_ahead_kb_values() {
	MemTotalStr=`cat /proc/meminfo | grep MemTotal`
	MemTotal=${MemTotalStr:16:8}

	dmpts=$(ls /sys/block/*/queue/read_ahead_kb | grep -e dm -e mmc -e sd)
	# dmpts holds below read_ahead_kb nodes if exists:
	# /sys/block/dm-0/queue/read_ahead_kb to /sys/block/dm-10/queue/read_ahead_kb
	# /sys/block/sda/queue/read_ahead_kb to /sys/block/sdh/queue/read_ahead_kb

	# Set 128 for <= 4GB &
	# set 512 for >= 5GB targets.
	if [ $MemTotal -le 4194304 ]; then
		ra_kb=128
	else
		ra_kb=512
	fi
	if [ -f /sys/block/mmcblk0/bdi/read_ahead_kb ]; then
		echo $ra_kb > /sys/block/mmcblk0/bdi/read_ahead_kb
	fi
	if [ -f /sys/block/mmcblk0rpmb/bdi/read_ahead_kb ]; then
		echo $ra_kb > /sys/block/mmcblk0rpmb/bdi/read_ahead_kb
	fi
	for dm in $dmpts; do
		if [ `cat $(dirname $dm)/../removable` -eq 0 ]; then
			echo $ra_kb > $dm
		fi
	done
}

function configure_vm_paramaters() {
	MemTotalStr=`cat /proc/meminfo | grep MemTotal`
	MemTotal=${MemTotalStr:16:8}
	let RamSizeGB="( $MemTotal / 1048576 ) + 1"

	# Set the min_free_kbytes and watermark_scale_factor value
	if [ $RamSizeGB -ge 12 ]; then
		# 12GB, 16GB
		MinFreeKbytes=11584
		WatermarkScale=30
	elif [ $RamSizeGB -ge 8 ]; then
		# 8GB
		MinFreeKbytes=11584
		WatermarkScale=40
	elif [ $RamSizeGB -ge 4 ]; then
		# 4GB, 6GB
		MinFreeKbytes=8192
		WatermarkScale=50
	elif [ $RamSizeGB -ge 2 ]; then
		# 2GB, 3GB
		MinFreeKbytes=5792
		WatermarkScale=50
	else
		# 1GB
		MinFreeKbytes=4096
		WatermarkScale=60
	fi

	echo $MinFreeKbytes  > /proc/sys/vm/min_free_kbytes
	echo $WatermarkScale > /proc/sys/vm/watermark_scale_factor
}

function dongfeng_configure_vm_paramaters() {
	MemTotalStr=`cat /proc/meminfo | grep MemTotal`
	MemTotal=${MemTotalStr:16:8}
	let RamSizeGB="( $MemTotal / 1048576 ) + 1"

	# Set the min_free_kbytes and watermark_scale_factor value
	if [ $RamSizeGB -ge 16 ]; then
		# 16GB
		MinFreeKbytes=23168
		WatermarkScale=33
	elif [ $RamSizeGB -ge 12 ]; then
		# 12GB
		MinFreeKbytes=27408
		WatermarkScale=24
	elif [ $RamSizeGB -ge 8 ]; then
		# 8GB
		MinFreeKbytes=22108
		WatermarkScale=22
	elif [ $RamSizeGB -ge 4 ]; then
		# 4GB, 6GB
		MinFreeKbytes=18924
		WatermarkScale=10
	elif [ $RamSizeGB -ge 2 ]; then
		# 2GB, 3GB
		MinFreeKbytes=5792
		WatermarkScale=50
	else
		# 1GB
		MinFreeKbytes=4096
		WatermarkScale=60
	fi

	echo $MinFreeKbytes  > /proc/sys/vm/min_free_kbytes
	echo $WatermarkScale > /proc/sys/vm/watermark_scale_factor
}
configure_read_ahead_kb_values
prjname=`getprop ro.boot.prjname`
if [[ "$prjname" == "24744" || "$prjname" == "24718" || "$prjname" == "24771" || "$prjname" == "24772" || "$prjname" == "24612" || "$prjname" == "24621" ]]; then
	dongfeng_configure_vm_paramaters
else
	configure_vm_parameters
fi

#Implementing this mechanism to jump to powersave governor if the script is not running
#as it would be an indication for devs for debug purposes.
fallback_setting()
{
        governor="powersave"
        for i in `ls -d /sys/devices/system/cpu/cpufreq/policy[0-9]*`
        do
                if [ -f $i/scaling_governor ] ; then
                        echo $governor > $i/scaling_governor
                fi
        done
}

if [ -f /sys/devices/soc0/chip_family ]; then
	chipfamily=`cat /sys/devices/soc0/chip_family`
fi

case "$chipfamily" in
	"0x9b")
		#Pass as an argument the max number of clusters supported on the SOC
		/vendor/bin/sh /vendor/bin/init.kernel.post_boot-volcano.sh 3
		;;
	*)
		echo "***WARNING***: Invalid chip family\n\t No postboot settings applied!!\n"
		fallback_setting
		;;
esac
