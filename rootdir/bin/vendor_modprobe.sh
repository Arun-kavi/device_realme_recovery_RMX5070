#! /vendor/bin/sh
#=============================================================================
# Copyright (c) 2019-2022 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#=============================================================================

VENDOR_DIR="/vendor/lib/modules"
VENDOR_DLKM_DIR="/vendor_dlkm/lib/modules"

MODPROBE="/vendor/bin/modprobe"

# vendor modules partition could be /vendor/lib/modules or /vendor_dlkm/lib/modules
POSSIBLE_DIRS="${VENDOR_DLKM_DIR} ${VENDOR_DIR}"
audio_arch=`getprop ro.boot.audio`

for dir in ${POSSIBLE_DIRS} ;
do
	if [ ! -e ${dir}/modules.load ]; then
		continue
	fi

	if [ "$audio_arch" == "audioreach" ]; then
		if [ -e ${dir}/modules.audio.ar.blocklist ]; then
			audio_blocklist_expr="$(sed -n -e 's/blocklist \(.*\)/\1/p' ${dir}/modules.audio.ar.blocklist | sed -e 's/-/_/g' -e 's/^/-e /')"
		fi
	else
		if [ -e ${dir}/modules.audio.legacy.blocklist ]; then
			audio_blocklist_expr="$(sed -n -e 's/blocklist \(.*\)/\1/p' ${dir}/modules.audio.legacy.blocklist | sed -e 's/-/_/g' -e 's/^/-e /')"
		fi
	fi

	# Use pattern if block list is empty so that all modules pass through grep below
	if [ "X${audio_blocklist_expr}" = "X" ]; then
		audio_blocklist_expr="-e %"
	fi

	if [ -e ${dir}/modules.blocklist ]; then
		blocklist_expr="$(sed -n -e 's/blocklist \(.*\)/\1/p' ${dir}/modules.blocklist | sed -e 's/-/_/g' -e 's/^/-e /')"
	fi

	# Use pattern if block list is empty so that all modules pass through grep below
	if [ "X${blocklist_expr}" = "X" ]; then
		blocklist_expr="-e %"
	fi

	#ifdef OPLUS_BUG_STABILITY
	#ZengHui@CONNECTIVITY.WIFI.HARDWARE.FTM, 2023/05/04,
	#Add for ftm mode do not probe qca_cld3 ko
	if [ "$(cat /sys/systeminfo/ftmmode)" == "3" ]; then
		blocklist_expr+=" -e qca_cld3_kiwi_v2"
	fi
	#endif /* OPLUS_BUG_STABILITY */

	#ifdef OPLUS_BUG_STABILITY
	#fangbinghua@CONNECTIVITY.WIFI.HARDWARE.SWITCH, 2024/03/08,
	#dont load qca6750 ko when platform is SM8650
	if [ "$(getprop ro.soc.model)" == "SM8650" ]; then
		blocklist_expr+=" -e qca_cld3_qca6750"
	fi
	#endif /* OPLUS_BUG_STABILITY */

	#ifdef OPLUS_BUG_STABILITY
	#fangbinghua@CONNECTIVITY.WIFI.HARDWARE.SWITCH, 2024/03/08,
	#dont load kiwi_v2 ko when platform is SM7675
	if [ "$(getprop ro.soc.model)" == "SM7675" ]; then
		blocklist_expr+=" -e qca_cld3_kiwi_v2"
	fi
	#endif /* OPLUS_BUG_STABILITY */

	# Filter out modules in blocklist - we would see unnecessary errors otherwise
	load_modules=$(sed = ${dir}/modules.load | sed 'N;s/\n/\t/' | sort -uk2 | sort -nk1 | cut -f2- | grep -w -v ${blocklist_expr} | grep -w -v ${audio_blocklist_expr})
	first_module=$(echo ${load_modules} | cut -d " " -f1)
	other_modules=$(echo ${load_modules} | cut -d " " -f2-)
	if ! ${MODPROBE} -b -s -d ${dir} -a ${first_module} > /dev/null ; then
		continue
	fi
	# load modules individually in case one of them fails to init
	for module in ${other_modules}; do
		( ${MODPROBE} -b -d ${dir} -a ${module} > /dev/null ) &
	done

	wait

	setprop vendor.all.modules.ready 1
	exit 0
done

exit 1
