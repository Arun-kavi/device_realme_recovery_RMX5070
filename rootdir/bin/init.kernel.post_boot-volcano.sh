#=============================================================================
# Copyright (c) 2024 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#=============================================================================

get_num_logical_cores_in_physical_cluster()
{
	i=0
	logical_cores=(0 0 0 0 0 0)
	if [ -f /sys/devices/system/cpu/cpu0/topology/cluster_id ] ; then
		physical_cluster="cluster_id"
	else
		physical_cluster="physical_package_id"
	fi
	for i in `ls -d /sys/devices/system/cpu/cpufreq/policy[0-9]*`
	do
		if [ -e $i ] ; then
			num_cores=$(cat $i/related_cpus | wc -w)
			first_cpu=$(echo "$i" | sed 's/[^0-9]*//g')
			cluster_id=$(cat /sys/devices/system/cpu/cpu$first_cpu/topology/$physical_cluster)
			logical_cores[cluster_id]=$num_cores
		fi
	done
	cpu_topology=""
	j=0
	physical_cluster_count=$1
	while [[ $j -lt $physical_cluster_count ]]; do
		cpu_topology+=${logical_cores[$j]}
		if [ $j -lt $physical_cluster_count-1 ]; then
			cpu_topology+="_"
		fi
		j=$((j+1))
	done
	echo $cpu_topology
}

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
	exit
}

#/*Add swappiness tunning parameters*/
function oplus_configure_tuning_swappiness() {
	local MemTotalStr=`cat /proc/meminfo | grep MemTotal`
	local MemTotal=${MemTotalStr:16:8}
	local para_path=/proc/sys/vm
	local kernel_version=`uname -r`

	if [[ "$kernel_version" == "6.1"* ]]; then
		para_path=/sys/module/oplus_bsp_zram_opt/parameters
	fi

	if [ $MemTotal -le 6291456 ]; then
		echo 0 > $para_path/vm_swappiness_threshold1
		echo 0 > $para_path/swappiness_threshold1_size
		echo 0 > $para_path/vm_swappiness_threshold2
		echo 0 > $para_path/swappiness_threshold2_size
	elif [ $MemTotal -le 8388608 ]; then
		echo 70  > $para_path/vm_swappiness_threshold1
		echo 2000 > $para_path/swappiness_threshold1_size
		echo 90  > $para_path/vm_swappiness_threshold2
		echo 1500 > $para_path/swappiness_threshold2_size
	else
		echo 70  > $para_path/vm_swappiness_threshold1
		echo 4096 > $para_path/swappiness_threshold1_size
		echo 90  > $para_path/vm_swappiness_threshold2
		echo 2048 > $para_path/swappiness_threshold2_size
	fi

	#/*Add swappiness tunning parameters for dongfeng*/
	prjname=`getprop ro.boot.prjname`
	if [[ "$prjname" == "24744" || "$prjname" == "24718" || "$prjname" == "24771" || "$prjname" == "24772" || "$prjname" == "24612" || "$prjname" == "24621" ]]; then
		if [ $MemTotal -le 6291456 ]; then
			echo 100 > $para_path/vm_swappiness_threshold1
			echo 10 > $para_path/swappiness_threshold1_size
			echo 100 > $para_path/vm_swappiness_threshold2
			echo 10 > $para_path/swappiness_threshold2_size
		elif [ $MemTotal -le 8388608 ]; then
			echo 100  > $para_path/vm_swappiness_threshold1
			echo 2000 > $para_path/swappiness_threshold1_size
			echo 120  > $para_path/vm_swappiness_threshold2
			echo 1500 > $para_path/swappiness_threshold2_size
		elif [ $MemTotal -le 12582912 ]; then
			echo 100  > $para_path/vm_swappiness_threshold1
			echo 4096 > $para_path/swappiness_threshold1_size
			echo 120  > $para_path/vm_swappiness_threshold2
			echo 2048 > $para_path/swappiness_threshold2_size
		elif [ $MemTotal -le 16777216 ]; then
			echo 70  > $para_path/vm_swappiness_threshold1
			echo 4096 > $para_path/swappiness_threshold1_size
			echo 90  > $para_path/vm_swappiness_threshold2
			echo 2048 > $para_path/swappiness_threshold2_size
		else
			echo 70  > $para_path/vm_swappiness_threshold1
			echo 4096 > $para_path/swappiness_threshold1_size
			echo 90  > $para_path/vm_swappiness_threshold2
			echo 2048 > $para_path/swappiness_threshold2_size
		fi
	fi
}

function piaget_configure_vm_parameters() {
	MemTotalStr=`cat /proc/meminfo | grep MemTotal`
	MemTotal=${MemTotalStr:16:8}
	prjname=`getprop ro.boot.prjname`
	let RamSizeGB="( $MemTotal / 1048576 ) + 1"

	if [[ "$prjname" == "24697" || "$prjname" == "24698" || "$prjname" == "24607" || "$prjname" == "24623" || "$prjname" == "24724" ]]; then
		# Set the min_free_kbytes and watermark_scale_factor value
		if [ $RamSizeGB -ge 12 ]; then
			# 12GB, 16GB
			MinFreeKbytes=11584
			WatermarkScale=30
		elif [ $RamSizeGB -ge 8 ]; then
			# 8GB
			MinFreeKbytes=11584
			WatermarkScale=25
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
	fi
}

variant=$(get_num_logical_cores_in_physical_cluster "$1")
echo "CPU topology: ${variant}"
case "$variant" in
	"4_3_1")
	/vendor/bin/sh /vendor/bin/init.kernel.post_boot-volcano_default_4_3_1.sh
	;;
	"4_2_1")
	/vendor/bin/sh /vendor/bin/init.kernel.post_boot-volcano_4_2_1.sh
	;;
	"4_3_0")
	/vendor/bin/sh /vendor/bin/init.kernel.post_boot-volcano_4_3_0.sh
	;;
	*)
	echo "***WARNING***: Postboot script not present for the variant ${variant}"
	fallback_setting
	;;
esac

#config fg and top cpu shares
echo 5120 > /dev/cpuctl/top-app/cpu.shares
echo 4096 > /dev/cpuctl/foreground/cpu.shares
echo 2048 > /dev/cpuctl/sstop/cpu.shares
echo 2048 > /dev/cpuctl/ssfg/cpu.shares

setprop vendor.post_boot.parsed 1

# colocation V3 settings
echo 1000 > /proc/sys/walt/sched_min_task_util_for_colocation

oplus_configure_tuning_swappiness
piaget_configure_vm_parameters
