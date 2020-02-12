#!/bin/sh

export PATH=/opt/bin:/opt/sbin:/sbin:/bin:/usr/sbin:/usr/bin:$PATH

# Author: ryzhov_al
# Adapted by TeHashX / contact@hqt.ro
# Version: 3.0

ansi_red="\033[1;31m";            # 红色字体
ansi_white="\033[1;37m";          # 白色字体
ansi_green="\033[1;32m";          # 绿色字体
ansi_yellow="\033[1;33m";         # 黄色字体
ansi_blue="\033[1;34m";           # 蓝色字体
ansi_bell="\007";                 # 响铃提示
ansi_blink="\033[5m";             # 半透明背景填充
ansi_std="\033[m";                # 常规无效果，作为后缀
ansi_rev="\033[7m";               # 白色背景填充
ansi_ul="\033[4m";                # 下划线

BOLD="\033[1m"
NORM="\033[0m"
INFO="$ansi_blue $(date +%Y年%m月%d日\ %X)：$ansi_std $ansi_blink 信息：$ansi_std"
ERROR="$ansi_blue $(date +%Y年%m月%d日\ %X)：$ansi_std $ansi_red$ansi_blink 错误：$ansi_std"
WARNING="$ansi_blue $(date +%Y年%m月%d日\ %X)：$ansi_std $ansi_yellow$ansi_blink 警告：$ansi_std"
INPUT="$ansi_blue $(date +%Y年%m月%d日\ %X)：$ansi_std $ansi_green$ansi_blink   =>  $ansi_std"

opkg=opkg
ENT_FOLD='entware'
Scripts_D="/etc/$ENT_FOLD"
Kernel_V=$(expr substr `uname -r` 1 3)

check_autorun()
{
echo -e $INFO 将 $2 添加到开机自启动……
case $OS in
	*Merlin*)
		CWS_X="$1/$2"
		if [ -f "/usr/bin/dbus" ]; then
			EOC=`dbus list __|grep "$1/$2"`
			Key1=`dbus list __|grep "$1/$2"|awk -F = '{print $1}'`	
			Key2=`dbus list __|grep "$1/$2"|awk -F = '{print $2}'`
			if [ "${EOC}" ]; then
				dbus remove "${Key1}" "${Key2}"
			fi
			if [ -f "$1/wan-start" ]; then
				CWS=`cat $1/wan-start|grep "${CWS_X}"`
				if [ -z "${CWS}" ]; then
					echo -e "${CWS_X}" >> "$1/wan-start"
				else
					sed -i "/$2/d" "$1/wan-start"
					echo -e "${CWS_X}" >> "$1/wan-start"
				fi
			else
				cat > "$1/wan-start" <<EOF
#!/bin/sh
${CWS_X}
EOF
			fi
			chmod 755 "$1/wan-start"
			if [ -z "$(dbus list __|grep "$1/wan-start")" ]; then
				dbus event onwanstart_wan-start "$1/wan-start"
			fi
		fi
		;;
	*LEDE*|*Openwrt*)
		[ ! -d "/etc/rc.d" ] && mkdir -p /etc/rc.d
		[ ! -L "/etc/rc.d/$2" ] && ln -nsf $1/$2 /etc/rc.d/$2 && mv -f /etc/rc.d/$2 /etc/rc.d/S99$2
		;;
	*DD-WRT*)
		[ ! -d "/jffs/etc/config" ] && mkdir -p /jffs/etc/config
		[ ! -L "/jffs/etc/config/S99$2" ] && ln -nsf $1/$2 /jffs/etc/config/$2 && mv -f /jffs/etc/config/$2 /jffs/etc/config/S99$2
		;;
	*)
		[ ! -f  "/etc/rc.local" ] && cat > "/etc/rc.local" <<EOF
#!/bin/sh
${CWS_X}
exit 0
EOF
		TASK=`cat /etc/rc.local|grep $1/$2`
		[ -z "$TASK" ] && sed -i "/exit/i${CWS_X}" /etc/rc.local >/dev/null 2>&1
esac
}

check_url() {
  if [ "`wget -S --no-check-certificate --spider --tries=3 $1 2>&1 | grep 'HTTP/1.1 200 OK'`" ]; then return 0; else return 1; fi
}

check_partition(){
local m
for m in 1 2 3 4 5; do
	n=$((m + 1))
	eval value$m=`df -h|grep $@|awk '{print $(eval echo '$n')}'`
done
echo -e "$ansi_red$value5$ansi_std [$ansi_yellow容量：$ansi_red$value1  $ansi_yellow已用空间：$ansi_red$value2  $ansi_yellow可用空间：$ansi_red$value3  $ansi_yellow已用空间比例：$ansi_red$value4$ansi_std]"
}

choose_partition(){
PART_TYPES="ext2|ext3|ext4|.*fat|.*ntfs|fuseblk|btrfs|ufsd"
echo -e $INFO 正在检查可用分区……
i=1
for mounted in $(/bin/mount | grep -E "$PART_TYPES" | grep -v -E "/opt|/boot|/root" | grep -v -E -w "/" | cut -d " " -f3) ; do
	echo -e " $ansi_yellow$ansi_bell[$i]$ansi_std --> `check_partition $mounted`"
	eval mounts$i="$mounted"
	i=$((i + 1))
done

if [ $i = "1" ]; then
	echo -e $ERROR 没有检查到 $PART_TYPES 格式的分区，正在退出……
	sleep 3
	exit 1
fi

echo -en $INFO 选择分区作为 $2 的 $3 [ 输入分区序号 1-$((i - 1))；输入 0 退出 ]：
while true; do
	read -r partitionNumber
	case $partitionNumber in
		0)
			echo -e $INFO 正在退出……
			sleep 3
			exit 1 ;;
		*)
			if [ ! $partitionNumber ]; then
				if [ $((i - 1)) = 1 ]; then
					eval $1=\$mounts"1"
					eval echo -e "\$INFO 已选择 \$ansi_yellow$"$1"\$ansi_std 作为 $2 的 $3。"
				else
					echo -en "$ERROR 输入的序号无效，请重新输入："
				fi
			elif [ $(echo $partitionNumber | awk '{print(/^[0-9]*$/)?"0":"1"}') = 1 ]; then
				echo -en "$ERROR 输入的序号无效，请重新输入："
			else
				if [[ $partitionNumber -lt 0 || $partitionNumber -gt $((i - 1)) ]]; then
					echo -en "$ERROR 输入的序号无效，请重新输入："
				else
					eval $1=\$mounts"$partitionNumber"
					eval echo -e "\$INFO 已选择 \$ansi_yellow$"$1"\$ansi_std 作为 $2 的 $3。"
					break 1
				fi
			fi ;;
	esac
done
}

valid_com(){
i=1
for n in $(echo $PATH|sed 's/:/ /g'); do
	if [ -f $n/$@ ]; then
		echo "com$i=$n/$@"
		eval com$i="$n/$@"
	fi
	i=$((i + 1))
done
}

create_swap(){
dd if=/dev/zero of=$1 bs=1024 count=$2
mkswap $1
chmod 0600 $1
swapon $1
}

diy_swap(){
#分区可用空间
a=`df -h|grep $entPartition|awk '{print $4}'`
#分区可用空间(字节数)
b=`df|grep $entPartition|awk '{print $4}'`

echo -e $INFO 分区可用空间为 $a

echo -e $INFO 虚拟内存的单位设置
echo -e ""$ansi_yellow"1. 单位：MB    2. 单位：GB$ansi_std"
echo -en "$INPUT 请输入虚拟内存的单位选项(默认值：1. 单位：MB )[ 1 - 2 ]："

while true; do
	read m
	case $m in
		2 )
			y=GB
			break ;;
		* )
			y=MB
			break ;;
	esac
done

local n
until [[ $n -gt 0 && $n -le $b ]] 2>/dev/null; do
	echo -en "$INPUT 请输入虚拟内存的参数(正整数)："
	read x
	if [ ! $x ]; then
		echo -e $ERROR 未输入数据，返回主菜单……
		continue 2
		sleep 1
	elif [ $(echo $x | awk '{print(/^[0-9]*$/)?"0":"1"}') = 1 ]; then
		echo -e $ERROR 输入的内容无效，请重新输入！
	elif [ $x -le 0 ]; then
		echo -e $ERROR 输入的内容无效，请重新输入！
	else
		case $y in
			MB )
				n=$(($x*1024)) ;;
			GB )
				n=$(($x*1024*1024)) ;;
		esac
		if [ $n -gt $b ]; then
			echo -e $ERROR 自定义的页面文件大小超出了分区可用大小，请重新输入！
		elif [ $n -gt 2097152 ]; then
				echo -en "$WARNING 自定义的页面大小文件大于 2 GB ，确认继续？ $ansi_yellow(y/n)$ansi_std"
				read -r z
				case $z in
					y|Y )
						echo -e $INFO 是，正在创建 $x$y 的分页文件……
						echo -e "$INFO 创建过程需要一些时间，请耐心等待……\n"
						;;
					n|N )
						echo -e "$INFO 否\n"
						n=*
						;;
					* )
						echo -e "$ERROR 无效的选择\n"
						n=*
						;;
				esac
		else
				echo -e $INFO 自定义的页面文件大小为 $x$y
				echo -e $INFO 正在创建 $x$y 的分页文件……
				echo -e $INFO 创建过程需要一些时间，请耐心等待……
		fi
	fi
done
create_swap /opt/swap $n
}

local_swap(){
t=`free|grep Swap|awk '{print $2}'`
u=`free|grep Swap|awk '{print $3}'`
f=`free|grep Swap|awk '{print $4}'`

i=1
for v in $t $u $f; do
	if [ $v -ge 1048576 ]; then
		swap_UNIT=GB
		v=$(echo "scale=2;$v/1048576"|bc)
	elif [ $v -ge 1024 ]; then
		swap_UNIT=MB
		v=$(echo "scale=2;$v/1024"|bc)
	elif [ $v -ge 1 ]; then
		swap_UNIT=KB
	elif [ $v -eq 0 ]; then
		swap_UNIT=
	fi
	eval size_$i="$v$swap_UNIT"
	i=$((i + 1))
done

echo -e "    当前虚拟内存：$ansi_yellow 总共：$ansi_red$size_1$ansi_std$ansi_yellow 已用：$ansi_red$size_2$ansi_std$ansi_yellow 可用：$ansi_red$size_3$ansi_std"
}

set_swap(){
while :
do
	clear
	echo -e "$ansi_yellow------------------------------------------------------------$ansi_std"
	echo -e "$ansi_yellow                     设备型号： `cat "/proc/sys/kernel/hostname"`$ansi_std"
	echo -e "$ansi_yellow------------------------------------------------------------$ansi_std"
	echo -e "$ansi_bell$ansi_yellow                        虚拟内存设置$ansi_std"
	echo -e "$ansi_yellow------------------------------------------------------------$ansi_std"
	local_swap
	echo -e "$ansi_yellow------------------------------------------------------------$ansi_std"
	echo -e "$ansi_green$ansi_bell设置分页文件大小(强烈推荐)$ansi_std"
	echo -e ""$ansi_yellow"1.$ansi_std 512MB"
	echo -e ""$ansi_yellow"2.$ansi_std 1024MB"
	echo -e ""$ansi_yellow"3.$ansi_std 2048MB (建议用于 MySQL 服务器或丛式服务器)"
	echo -e ""$ansi_yellow"4.$ansi_std 自定义页面文件大小 (注意：设置数值不大于分区可用空间，且一般不大于 2048MB)"	
	echo -e ""$ansi_yellow"5.$ansi_std 跳过设置(已经配置虚拟内存可不用设置)"
	read -p "输入选项序号[ 1 - 5 ]：" choice
	case "$choice" in
		1)
			echo -e $INFO 正在创建 512MB 的分页文件……
			echo -e $INFO 创建过程需要一些时间，请耐心等待……
			create_swap /opt/swap 524288
			read -p "点击 [回车键] 继续……" readEnterKey
			local_swap
			break
			;;
		2)
			echo -e $INFO 正在创建 1024MB 的分页文件……
			echo -e $INFO 创建过程需要一些时间，请耐心等待……
			create_swap /opt/swap 1048576
			read -p "点击 [回车键] 继续……" readEnterKey
			local_swap
			break
			;;
		3)
			echo -e $INFO 正在创建 2048MB 的分页文件……
			echo -e $INFO 创建过程需要一些时间，请耐心等待……
			create_swap /opt/swap 2097152
			read -p "点击 [回车键] 继续……" readEnterKey
			local_swap
			break
			;;			
		4)
			diy_swap
			read -p "点击 [回车键] 继续……" readEnterKey
			local_swap
			break
			;;	
		5)
			local_swap
			break
			;;
		*)
			echo -e "$ERROR 无效的选择\n"
			echo "输入 1 创建 512MB 的分页文件"
			echo "输入 2 创建 1024MB 的分页文件"
			echo "输入 3 创建 2048MB 的分页文件"
			echo "输入 4 自定义分页文件大小"			
			echo "输入 5 不创建分页文件(不建议)" 
			read -p "点击 [回车键] 继续……" readEnterKey
			;;
	esac	
done
}

#if [ "`find / -name id`" ]; then
#	if [ "$(id -u)" != "0" ]; then
#		echo -e $ERROR 请使用 root 账号或者具有 root 权限的账号运行进行 Entware-NG 的安装！
#		sleep 5
#		exit 1
#	fi
#fi

cd /tmp || exit

echo -e $INFO 脚本原作者：ryzhov_al 版本：V3.0
echo -e $INFO 修改作者：TeHashX，泽泽酷儿
echo -e $INFO 汉化：泽泽酷儿
echo -e $INFO 鸣谢 @zyxmon \& @ryzhov_al 致力于开发 New Generation Entware
echo -e $INFO 鸣谢 @Rmerlin 致力于开发优秀的 Merlin 固件
sleep 2
echo -e $INFO 本脚本将引导您完成 Entware 环境的安装。
echo -e $INFO 执行过程仅影响所选驱动器路径下的 \"entware\" 文件夹，
echo -e $INFO 而不会影响到别的数据。以前安装的环境将会替换为当前版本，
echo -e $INFO 过程中也会安装一些自启动的脚本，而旧的脚本文件将会打包
echo -e $INFO 备份在安装 Entware 的分区，
echo -e $INFO 例如 /tmp/mnt/sda1/jffs_scripts_backup.tgz
echo

OS=$(/bin/uname -o)

case $OS in
  *Merlin*)
	OS=Merlin
	Scripts_D="/jffs/scripts"
    echo -e $INFO 当前设备固件为 $OS	
	;;
  *DD-WRT*)
	OS=DD-WRT
	Scripts_D="/jffs/etc/$ENT_FOLD"
	Kernel_V="3.2"
    echo -e $INFO 当前设备固件为 $OS	
	;;
  *LEDE*)
	OS=LEDE
    echo -e $INFO 当前设备固件为 $OS	
	;;
  *Openwrt*)
	OS=Openwrt
    echo -e $INFO 当前设备固件为 $OS	
	;;
  *Linux*)
	OS=Linux
    echo -e $INFO 当前设备固件为 $OS	
	;;
  *)
    echo -e $ERROR 暂时不支持您的设备
    echo -e $ERROR 正在退出……
	sleep 3
    exit 1
esac

case $OS in
	*Merlin*)
		echo -e $INFO 检查 JFFS 自定义脚本和配置……
		if [ "$(nvram get jffs2_enable)" != "1" ] || [ "$(nvram get jffs2_scripts)" != "1" ]; then
			if [ "$(nvram get jffs2_enable)" != "1" ]; then
				echo -e $WARNING 未发现 JFFS 分区，正在启用……
				nvram set jffs2_enable=1
				nvram commit
			fi
			if [ "$(nvram get jffs2_scripts)" != "1" ]; then
				echo -e $WARNING 未配置 JFFS 自定义脚本，正在启用……
				nvram set jffs2_scripts=1
				nvram set jffs2_format=1
				nvram commit
			fi
			echo -e $INFO 配置完成，请重启设备后重新运行脚本……
			sleep 10
    		exit 1
		fi
		;;
	*DD-WRT*)
		echo -e $INFO 检查 JFFS 自定义脚本和配置……
		if [ "$(nvram get enable_jffs2)" != "1" ] || [ "$(nvram get sys_enable_jffs2)" != "1" ] || [ "$(nvram get usb_enable)" != "1" ] || [ "$(nvram get usb_storage)" != "1" ] || [ "$(nvram get usb_automnt)" != "1" ]; then
			if [ "$(nvram get enable_jffs2)" != "1" ]; then
				echo -e $WARNING 未发现 JFFS 分区，正在启用……
				nvram set enable_jffs2=1
				nvram set clean_jffs2=1
				nvram commit
			fi
			if [ "$(nvram get sys_enable_jffs2)" != "1" ]; then
				echo -e $WARNING 未配置 JFFS 自定义脚本，正在启用……
				nvram set sys_enable_jffs2=1
				nvram set sys_clean_jffs2=1
				nvram commit
			fi
			if [ "$(nvram get usb_enable)" != "1" ]; then
				echo -e $INFO 未配置 核心 USB 支持，正在启用……
				nvram set usb_enable=1
				nvram commit
			fi
			if [ "$(nvram get usb_storage)" != "1" ]; then
				echo -e $INFO 未配置 USB 存储设备支持，正在启用……
				nvram set usb_storage=1
				nvram commit
			fi
			if [ "$(nvram get usb_automnt)" != "1" ]; then
				echo -e $INFO 未配置 USB 存储自动挂载支持，正在启用……
				nvram set usb_automnt=1
				nvram commit
			fi
			echo -e $INFO 配置完成，请重启设备后重新运行脚本……
			sleep 10
    		exit 1
		fi
		;;
	*)
		;;
esac

echo -e $INFO 查看分区挂载情况
df -T -h

PLATFORM=$(uname -m)

if [ "$PLATFORM" == "aarch64" ]
then
   echo -e $INFO 本设备支持安装64位及32位 Entware 环境
   echo -e $INFO 建议安装64位版本，但如果需要使用一些32位的应用，
   echo -e $INFO 可能需要32位版本支持。
   echo -e $INFO 64位版本针对新版内核更加优化。
   echo ""
   echo -en "$INPUT 是否安装64位版本？ $ansi_yellow(y/n)$ansi_std"

  read -r choice
  case "$choice" in
   y|Y )
     echo -e "$INFO 正在安装64位版本。\n"
     PLATFORM="aarch64"
     ;;
   n|N )
     echo -e "$INFO 正在安装32位版本。\n"
     PLATFORM="armv7l"
     ;;
  * )
     echo -e "$ERROR 无效的选择 - 正在退出……\n"
     exit
     ;;
  esac
fi

case $PLATFORM in
  armv7l)    
    INST_URL=http://bin.entware.net/armv7sf-k${Kernel_V}/installer/generic.sh
    ;;
  mips)
    INST_URL=http://bin.entware.net/mipselsf-k3.4/installer/generic.sh
    if [ $Kernel_V == "2.6" ]; then
        INST_URL=http://pkg.entware.net/binaries/mipsel/installer/installer.sh
    fi
    ;;
  armv5*)
    INST_URL=http://bin.entware.net/armv5sf-k3.2/installer/generic.sh
    ;;
  aarch64)
    INST_URL=http://bin.entware.net/aarch64-k3.10/installer/generic.sh
    ;;
  x86_32)
    INST_URL=http://pkg.entware.net/binaries/x86-32/installer/entware_install.sh
    ;;
  x86_64)
    INST_URL=http://bin.entware.net/x64-k3.2/installer/generic.sh
    ;;
  *)
    echo -e $ERROR 抱歉，不支持您的设备！
    exit 1
    ;;
esac

choose_partition entPartition Entware-NG 安装驱动器
entFolder="$entPartition/$ENT_FOLD"
entwareFolder="$entPartition/entware-ng"
entwarearmFolder="$entPartition/entware-ng.arm"
asuswareFolder="$entPartition/asusware"
asuswarearmFolder="$entPartition/asusware.arm"
optwFolder="$entPartition/optware"
optwareFolder="$entPartition/optware-ng"
optwarearmFolder="$entPartition/optware-ng.arm"
optswap=`find $entFolder $entwareFolder $entwarearmFolder $asuswareFolder $asuswarearmFolder $optwFolder $optwareFolder $optwarearmFolder -name swap 2>/dev/null`

if [ -d /opt/debian ]
then
	echo -e $WARNING 发现 debian 系统，正在关闭……
	debian stop
fi

if [ -f /opt/etc/init.d/rc.unslung ]; then
	echo -e $WARNING 正在停止 Entware-NG 的相关服务……
	/opt/etc/init.d/rc.unslung kill
fi

for i in post-mount services-start services-stop unmount; do
	if [ -f /etc/rc.d/S99$i ]; then
		rm -rf /etc/rc.d/S99$i
	elif [ -f "/etc/rc.local" ]; then
		if [ -n "$(cat /etc/rc.local|grep $i)" ]; then
			sed -i "/$i/d" /etc/rc.local >/dev/null 2>&1
		fi
	elif [ -f "$Scripts_D/wan-start" ]; then
		if [ -n "$(cat $Scripts_D/wan-start|grep $i)" ]; then
			sed -i "/$i/d" $Scripts_D/wan-start >/dev/null 2>&1
		fi	
	fi
done

if [ -f $Scripts_D/post-mount -o -f $Scripts_D/services-start -o -f $Scripts_D/services-stop -o -f $Scripts_D/unmount ]; then
	echo -e $INFO 正在创建脚本备份……
	tar -czf "$entPartition/scripts_backup_$(date +%F_%H-%M).tgz" $Scripts_D/* 2>/dev/null
	rm -rf $Scripts_D/post-mount $Scripts_D/services-start $Scripts_D/services-stop $Scripts_D/unmount
fi

if [ -f "$optswap" ]; then
	echo -e $WARNING 发现之前环境的虚拟内存文件，正在移除……
	swapoff ${optswap} 2>/dev/null
	rm -rf ${optswap} 2>/dev/null
fi

if [ -d "$entFolder" ]; then
	echo -e $WARNING 发现之前安装的 entware-ng 环境，正在备份……
	mv "$entFolder" "$entFolder-old_$(date +%F_%H-%M)"
fi

if [ -d "$entFolder" ]; then
	echo -e $WARNING 发现之前安装的 entware-ng 环境，正在备份……
	mv "$entFolder" "$entFolder-old_$(date +%F_%H-%M)"
fi

if [ -d "$entwareFolder" ]; then
	echo -e $WARNING 发现之前安装的 entware-ng 环境，正在备份……
	mv "$entwareFolder" "$entwareFolder-old_$(date +%F_%H-%M)"
fi

if [ -d "$entwarearmFolder" ]; then
	echo -e $WARNING 发现之前安装的 entware-ng 环境，正在备份……
	mv "$entwarearmFolder" "$entwarearmFolder-old_$(date +%F_%H-%M)"
fi

if [ -d "$asuswareFolder" ]; then
	echo -e $WARNING 发现之前安装的 optware 环境，正在备份……
	mv "$asuswareFolder" "$asuswareFolder-old_$(date +%F_%H-%M)"
fi

if [ -d "$asuswarearmFolder" ]; then
	echo -e $WARNING 发现之前安装的 optware.arm 环境，正在备份……
	mv "$asuswarearmFolder" "$asuswarearmFolder-old_$(date +%F_%H-%M)"
fi

if [ -d "$optwFolder" ]; then
	echo -e $WARNING 发现 optware 环境，正在备份……
	mv "$optwFolder" "$optwFolder-old_$(date +%F_%H-%M)"
fi

if [ -d "$optwareFolder" ]; then
	echo -e $WARNING 发现 optware-ng 环境，正在备份……
	mv "$optwareFolder" "$optwareFolder-old_$(date +%F_%H-%M)"
fi

if [ -d "$optwarearmFolder" ]; then
	echo -e $WARNING 发现 optware.ng.arm 环境，正在备份……
	mv "$optwarearmFolder" "$optwarearmFolder-old_$(date +%F_%H-%M)"
fi

echo -e $INFO 正在创建 $entFolder 文件夹……
mkdir -p "$entFolder"

[ ! -d $Scripts_D ] && echo -e $INFO 正在创建脚本目录…… && mkdir -p $Scripts_D

case $OS in
	*Merlin*)
		if [ -e /tmp/opt ]; then
			echo -e $WARNING 正在删除 /tmp/opt 符号链接……
			rm -rf /tmp/opt > /dev/null
		fi
		;;
	*)
		rm -rf /opt/* > /dev/null
		rm -rf /opt > /dev/null
		if [ "$(valid_com fuser)" ]; then
			if [ "`fuser -m /opt`" ]; then
				fuser -km /opt
			fi
		fi
		if [ -z "(/bin/mount | grep -E /opt)" ]; then
			umount -f /opt > /dev/null
		fi
		;;
esac

case $OS in
	*Merlin*)
		echo -e $INFO 正在创建 /opt 符号链接……
		ln -nsf "$entFolder" /tmp/opt
		;;
	*DD-WRT*)
		echo -e $INFO 正在挂载 /opt 分区……
		mount -o rw $entFolder /opt 
		;;
	*)
		if [ -d /opt ]; then
			echo -e $INFO 正在挂载 /opt 分区……
			mount -o rw $entFolder /opt
		else
			echo -e $INFO 正在创建 /opt 符号链接……
			ln -nsf "$entFolder" /opt
		fi
		;;
esac

[ ! -d /opt ] && echo -e "$ERROR 创建/挂载 opt 分区失败，正在退出……\n" && exit

echo -e $INFO 正在创建服务脚本……
cat > $Scripts_D/services-start << EOF
#!/bin/sh

RC='/opt/etc/init.d/rc.unslung'

i=30
until [ -x "\$RC" ] ; do
  i=\$((\$i-1))
  if [ "\$i" -lt 1 ]; then
    logger "无法启动 Entware 环境"
    exit
  fi
  sleep 5
done
\$RC start
EOF
chmod +x $Scripts_D/services-start

cat > $Scripts_D/services-stop << EOF
#!/bin/sh

/opt/etc/init.d/rc.unslung kill
EOF
chmod +x $Scripts_D/services-stop

cat > $Scripts_D/post-mount << 'EOF'
#!/bin/sh

ENT_FOLD='entware'
Scripts_D="/etc/$ENT_FOLD"
Kernel_V=$(expr substr `uname -r` 1 3)

check_OS(){
OS=$(/bin/uname -o)

case $OS in
    *Merlin*)
        OS=Merlin
        Scripts_D="/jffs/scripts"
        ;;
    *DD-WRT*)
        OS=DD-WRT
        Scripts_D="/jffs/etc/$ENT_FOLD"
        ;;
    *LEDE*)
        OS=LEDE
        ;;
    *Openwrt*)
        OS=Openwrt
        ;;
    *Linux*)
        OS=Linux
        ;;
    *)
        echo -e $ERROR 暂时不支持您的设备
        echo -e $ERROR 正在退出……
        sleep 3
        exit 1
esac
}

valid_com(){
i=1
for n in $(echo $PATH|sed 's/:/ /g'); do
    if [ -f $n/$@ ]; then
        echo "com$i=$n/$@"
        eval com$i="$n/$@"
    fi
    i=$((i + 1))
done
}

Ent_exist(){
[ -f /opt/var/opkg-lists/entware ] && return 0 || return 1
}

re_Ent(){
if ! ( Ent_exist ); then
    PART_TYPES="ext2|ext3|ext4|.*fat|.*ntfs|fuseblk|btrfs|ufsd"
    echo -e $INFO 正在检查 Entware-NG 安装分区……
    for mounted in $(/bin/mount | grep -E "$PART_TYPES" | grep -v -E "/opt|/boot|/root" | grep -v -E -w "/" | cut -d " " -f3) ; do
        if [ -f $mounted/entware/var/opkg-lists/entware ]; then
            eval entPartition="$mounted"
            entFolder="$entPartition/$ENT_FOLD"
        fi
    done
	
    case $OS in
        *Merlin*)
            if [ -e /tmp/opt ]; then
                echo -e $WARNING 正在删除 /tmp/opt 符号链接……
                rm -rf /tmp/opt > /dev/null
            fi
            ;;
        *)
            rm -rf /opt/* > /dev/null
            rm -rf /opt > /dev/null
            if [ "$(valid_com fuser)" ]; then
                if [ "`fuser -m /opt`" ]; then
                    fuser -km /opt
                fi
            fi
            if [ -z "(/bin/mount | grep -E /opt)" ]; then
                umount -f /opt > /dev/null
            fi
            ;;
    esac

    case $OS in
        *Merlin*)
            echo -e $INFO 正在创建 /opt 符号链接……
            ln -nsf "$entFolder" /tmp/opt
            ;;
        *DD-WRT*)
            echo -e $INFO 正在挂载 /opt 分区……
            mount -o rw $entFolder /opt 
            ;;
        *)
            if [ -d /opt ]; then
                echo -e $INFO 正在挂载 /opt 分区……
                mount -o rw $entFolder /opt
            else
                echo -e $INFO 正在创建 /opt 符号链接……
                ln -nsf "$entFolder" /opt
            fi
            ;;
    esac
    Ent_exist
fi
}

service_opt(){
local seconds=0
while ! ( re_Ent )
    do
        seconds=$(( $seconds + 1 ))
        echo -n " ."
        sleep 1
        if [ $seconds = 20 ]; then
            echo
            return 1
        fi
    done
}

start_opt(){
if ( re_Ent ); then
    echo -e $INFO 已经挂载 Entware-NG ！
fi
if ( service_opt ); then
    echo -e $INFO 已经启动 Entware-NG ！
else
    echo -e $WARNING 无法启动 Entware-NG ！
fi
}

check_OS
start_opt

sleep 2

. /opt/etc/profile
if [ -f /opt/swap ]; then
    echo -e $INFO 正在挂载虚拟内存文件……
    swapon /opt/swap
fi
EOF
chmod +x $Scripts_D/post-mount

cat > $Scripts_D/unmount << 'EOF'
#!/bin/sh

awk '/SwapTotal/ {if($2>0) {system("swapoff /opt/swap")} else print "未挂载虚拟内存"}' /proc/meminfo
EOF
chmod +x $Scripts_D/unmount

check_autorun $Scripts_D post-mount
check_autorun $Scripts_D services-start

if [ -f /bin/opkg ]; then
	mv -f /bin/opkg /bin/opkg_ori
	opkg=/opt/bin/opkg
fi

if check_url $INST_URL; then
	echo -e $INFO Entware-NG 官网连接成功，开始安装 Entware-NG ……
	wget -t 5 -qcNO - $INST_URL | sh
	opkg update && opkg upgrade
else
	echo -e $ERROR Entware-NG 官网连接失败，请检查网络连接状态后重试！
	sleep 5
	exit 1
fi


i18n_URL=http://pkg.entware.net/sources/i18n_glib223.tar.gz

if check_url $i18n_URL; then
	echo -e $INFO i18n 链接连接成功，开始安装 i18n ……
	wget -qcNO- -t 5 $i18n_URL | tar xvz -C /opt/usr/share/ > /dev/null
	echo "Adding zh_CN.UTF-8"
	/opt/bin/localedef.new -c -f UTF-8 -i zh_CN zh_CN.UTF-8
	sed -i 's/en_US.UTF-8/zh_CN.UTF-8/g' /opt/etc/profile
else
	echo -e $ERROR i18n 链接连接失败，请检查网络连接状态后重试！
	sleep 5
fi

# 汉化启动脚本
#sed -i 's/Starting/正在启动/g' /opt/etc/init.d/rc.func
#sed -i 's/\.\.\./ ……/g' /opt/etc/init.d/rc.func
#sed -i 's/already running./已经在运行。/g' /opt/etc/init.d/rc.func
#sed -i 's/failed./失败。/g' /opt/etc/init.d/rc.func
#sed -i 's/done./完成。/g' /opt/etc/init.d/rc.func
#sed -i 's/Shutting down/正在停止/g' /opt/etc/init.d/rc.func
#sed -i 's/Killing/正在结束/g' /opt/etc/init.d/rc.func
#sed -i 's/Checking $DESC/正在检查 $DESC 运行状态/g' /opt/etc/init.d/rc.func
#sed -i 's/alive./正在运行。/g' /opt/etc/init.d/rc.func
#sed -i 's/dead./未运行。/g' /opt/etc/init.d/rc.func
#sed -i 's/Sending $SIGNAL to $PROC/$PROC 正在重新加载配置文件/g' /opt/etc/init.d/rc.func
#sed -i 's/Usage:/命令：/g' /opt/etc/init.d/rc.func

cat > /opt/etc/init.d/rc.func << 'EOF'
#!/bin/sh

ACTION=$1

ansi_red="\033[1;31m";            # 红色字体
ansi_white="\033[1;37m";          # 白色字体
ansi_green="\033[1;32m";          # 绿色字体
ansi_yellow="\033[1;33m";         # 黄色字体
ansi_blue="\033[1;34m";           # 蓝色字体
ansi_bell="\007";                 # 响铃提示
ansi_blink="\033[5m";             # 半透明背景填充
ansi_std="\033[m";                # 常规无效果，作为后缀
ansi_rev="\033[7m";               # 白色背景填充
ansi_ul="\033[4m";                # 下划线

BOLD="\033[1m"
NORM="\033[0m"
INFO="$ansi_blue $(date +%Y年%m月%d日\ %X)：$ansi_std $ansi_blink 信息：$ansi_std"
ERROR="$ansi_blue $(date +%Y年%m月%d日\ %X)：$ansi_std $ansi_red$ansi_blink 错误：$ansi_std"
WARNING="$ansi_blue $(date +%Y年%m月%d日\ %X)：$ansi_std $ansi_yellow$ansi_blink 警告：$ansi_std"
INPUT="$ansi_blue $(date +%Y年%m月%d日\ %X)：$ansi_std $ansi_green$ansi_blink   =>  $ansi_std"

KILLSTATUS='askkill'
KILLSIGNAL='-2'
LOG="/dev/null"

service_running(){
pidof $PROC > /dev/null
}

ask_user(){
echo -en "$WARNING 无法关闭 $PROC, 使用 kill -9 强行杀死进程？$ansi_yellow(y/n)$ansi_blink"
while true
  do
    read answer
    case $answer in [Yy]* ) return 0 ;;
                    [Nn]* ) return 1 ;;
                        * ) echo -e "/n$INPUT 输入 y 或 n";;
    esac
  done
}

start_service(){
local seconds=0

echo -en "$INFO 正在启动 $PROC "
$PREARGS $PROC $ARGS > $LOG 2>&1 &

while ! (service_running)
  do
    seconds=$(( $seconds + 1 ))
    echo -n "."
    sleep 1
    if [ $seconds = 10 ]; then
      echo
      return 1
    fi
  done

echo
return 0
}

stop_service(){
local seconds=0

if [ $1 = '-1' ]; then
  echo -en "$INFO 正在使用 kill $1 重新加载 $PROC 的配置文件"
else
  echo -en "$INFO 正在使用 kill $1 关闭 $PROC"
fi

kill $1 $PID

while ( service_running )
  do
     seconds=$(( $seconds + 1 ))
     echo -n " ."
     sleep 1
     if [ $seconds = 20 ]; then
       echo
       return 1
     fi
  done

echo
return 0
}

start(){
if ( service_running ); then
  echo -e "$INFO 正在运行 $PROC ！"
fi
if ( start_service ); then
  echo -e "$INFO 已经启动 $PROC ！" | tee -a "$LOG"
else
  echo -e "$WARNING 无法启动 $PROC ！" | tee -a "$LOG"
fi
}

stop(){
if ! ( service_running ); then
  echo -e "$INFO $PROC 未运行！"
else
  if ! ( stop_service $KILLSIGNAL ); then
    case $KILLSTATUS in
      "autokill" )
        KILLSIGNAL='-9'
        stop_service $KILLSIGNAL ;;
      "askkill" )
        if ( ask_user ); then
          KILLSIGNAL='-9'
          stop_service $KILLSIGNAL
        fi ;;
    esac
  fi

  if ( service_running ); then
    echo -e "$WARNING 无法使用 kill $KILLSIGNAL 关闭 $PROC ！" | tee -a "$LOG"
    exit 1
  else
    echo -e "$INFO 已使用 kill $KILLSIGNAL 关闭 $PROC ！" | tee -a "$LOG"
  fi
fi
}

check(){
if ( service_running ); then
  echo -e "$INFO $PROC 正在运行！"
else
  echo -e "$INFO $PROC 未运行！"
fi
}

reconfigure() {
if ( service_running ); then
  KILLSIGNAL='-1'
  stop_service $KILLSIGNAL
else
  echo -e "$INFO $PROC 未运行！"
fi
}

for PROC in $PROCS; do
  PID=$(pidof $PROC)
    case $ACTION in
        start)
            start
            ;;
        stop | kill )
            stop
            ;;
        restart)
            stop && start
            ;;
        check)
            check
            ;;
        reconfigure)
            reconfigure
            ;;
        *)
            check && echo -e "$ansi_white 命令： $0 (启动：start|停止：stop|重启：restart|检查：check|杀死进程：kill|重载配置：reconfigure)$ansi_std"
            exit 1
            ;;
    esac
done

echo -e "$INFO 没有遇到任何问题" >> "$LOG"
EOF

sed -i "s#PATH=.*#PATH=/opt/sbin:/opt/bin:/opt/usr/sbin:/opt/usr/bin:/koolshare/bin:/koolshare/scripts:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin#" /opt/etc/init.d/rc.unslung
sed -i "/CALLER=/a\entPartition=$entPartition" /opt/etc/init.d/rc.unslung

# 设置虚拟内存
opkg install bc
set_swap

#Delete entware_backup
if [ "$(find / -name entware*bak* -o -name entware*old*)" ]; then
  echo -en "$INPUT 是否删除旧的 Entware 环境备份？ $ansi_yellow(y/n)$ansi_std"
  read choice
  case "$choice" in
   n|N )
     ;;
   * )
     echo -e "\n$INFO 正在删除旧的 Entware 环境备份……"
     rm -rf `find / -name entware*bak* -o -name entware*old*`
     ;;
  esac
fi

#Delete scripts_backup
if [ "$(find / -name scripts_backup_*.tgz)" ]; then
  echo -en "$INPUT 是否删除旧的脚本备份？ $ansi_yellow(y/n)$ansi_std"
  read choice
  case "$choice" in
   n|N )
     ;;
   * )
     echo -e "\n$INFO 正在删除旧的脚本备份……"
     rm -rf `find / -name scripts_backup_*.tgz`
     ;;
  esac
fi

cat > /opt/bin/services << EOF
#!/bin/sh

export PATH=/opt/bin:/opt/sbin:/sbin:/bin:/usr/sbin:/usr/bin$PATH

case "\$1" in
 start)
   . $Scripts_D/services-start
   ;;
 stop)
   . $Scripts_D/services-stop
   ;;
 restart)
   . $Scripts_D/services-stop
   echo -e 正在重启 Entware 环境相关服务……
   sleep 2
   . $Scripts_D/services-start
   ;;
 *)
   echo "命令：“服务名称 {start|stop|restart}” 实现服务的{启动|停止|重启}功能" >&2
   exit 3
   ;;
esac
EOF
chmod +x /opt/bin/services

cat << EOF

恭喜！安装过程未报错意味着 Entware 环境已成功初始化。

如果在使用过程中发现 Bug，欢迎反馈至 https://github.com/Entware-ng/Entware-ng/issues

您可以使用 '$opkg install 服务名称' 命令进行软件包安装。

EOF

if [ -f /bin/opkg_ori ]; then
	mv -f /bin/opkg_ori /bin/opkg
fi
