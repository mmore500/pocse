#!/bin/bash

resDir="res"
colorCodes="$resDir/colorCodes"
refDir='Pop_Theme_reference'
modDir='Pop_Theme_modified'
colorsJson="$resDir/colors.json"

hexToRGB () {
	hex=$1
	printf "%d %d %d\n" 0x${hex:0:2} 0x${hex:2:2} 0x${hex:4:2}
}

getClosestColor () {
	ir=$1
	ig=$2
	ib=$3
	colors=`cat $colorsJson`
    max=`echo $colors | jq '. | length'`
	minOffset=765 #3x255
	declare -A colorArray
	for (( i=0; i<$max; i++ ))
	do	
		color=`echo $colors | jq ".[$i]"`
		r=`echo $color | jq ".rgb.r"`
		g=`echo $color | jq ".rgb.g"`
		b=`echo $color | jq ".rgb.b"`
		offsetR=$((ir-r))
		offsetG=$((ig-g))
		offsetB=$((ib-b))

		if [ $offsetR -lt 0 ] ; then offsetR=$((0-offsetR)) ; fi
		if [ $offsetG -lt 0 ] ; then offsetG=$((0-offsetG)) ; fi
		if [ $offsetB -lt 0 ] ; then offsetB=$((0-offsetB)) ; fi

		offset=$((offsetR+offsetG+offsetB))

		if [ $offset -le $minOffset ]
		then
			if [ ${colorArray[$offset]+_} ] 
			then colorArray["$offset"]+=", $color"
			else colorArray["$offset"]=$color
			fi
			minOffset=$offset
		fi
	done
	echo ${colorArray["$minOffset"]} | jq '.'
}

colorCodeCached () {
	code="-1"
	while read l ; do
		line=($l)
		if [ $1 == ${line[0]} ] ; then code=${line[1]} ; fi
	done < $colorCodes
	echo $code
}

getColorCode () {
	hex=$1
	code=0
	if [[ ${#hex} -eq 7 ]]
	then
		hex="${hex:1}"
		if [[ $hex =~ ^[0-9A-Fa-f]{6}$ ]]
		then
			touch $colorCodes
			code=`colorCodeCached $hex`
			if [ $code == "-1" ] 
			then
				rgb=(`hexToRGB $hex`)
				r=${rgb[0]}
				g=${rgb[1]}
				b=${rgb[2]}
				color=`getClosestColor $r $g $b`
				code=`echo $color | jq ".colorId"`
				echo "$hex $code" >> $colorCodes
			fi
		fi
	fi
    echo $code
}

d=false
i=false
r=false
c=false
w=false
man='Usage: pop_customization [OPTIONS] \nGenerates a Pop OS based theme with a custom color scheme. \n	-d	Force download of reference theme from Pop OS git repo.\n	-i	Install theme after customization\n	-r	Reset installed theme to vanilla Pop OS theme.\n	-h	Display this help and exit.\n	-c	Use terminal colors for preview (compatible with most modern terminals)\n	-w	Wipe local resources previously generated by the script'

if [ $# -ne 0 ]
then
	for arg in "$@"
	do
		case $arg in
		"-d")
			d=true
			;;
		"-i")
			i=true
			;;
		"-r")
			echo "-r isn't yet implemented"
			r=true
			exit
			;;
		"-h")
			echo -e $man
			exit
			;;
		"-c")
			c=true
			;;
		"-w")
			w=true
			;;
		*)
			echo "Unknown argument $arg"
			exit
			;;
		esac
	done
fi

if $w
then
	rm -r $refDir
	rm -r $resDir
fi

mkdir $resDir

if ! $d
then
	if [ ! -d $refDir ]
	then 
		echo "Reference theme not locally available, do you want to download it ? [Y/n]"
		read input
		case $input in
		"y"|"yes"|""|"Yes"|"Y")
			d=true
			;;
		*)
			exit
			;;
		esac
	fi
fi

if $d 
then
	echo "Get official Pop OS theme from git repo." 
	rm -r $refDir
	git clone https://github.com/pop-os/gtk-theme.git $refDir
fi

if $c
then
	if ! [ -f $colorsJson ]
	then
		echo "Reference color codes not locally available, do you want to download them ? [Y/n]"
		read input
		case $input in
		"y"|"yes"|""|"Yes"|"Y")
			curl https://jonasjacek.github.io/colors/data.json | jq . > $colorsJson
			;;
		*)
			c=false
			;;
		esac
	fi
fi

count=0
while read l; do
	((count++))
	print=false
	dark=false
	case $l in
	*"- Orange:"*)
		color="Orange: "
		;;
	*"- Blue:"*)
		color="Blue: "
		;;
	*"- Window background:"*)
		color="Window Background: "
		;;
	*"- Header/Title Bars:"*)
		color="Header/Title Bars: "
		;;
	*"- Dark theme:"*)
		dark=true
		words=($l)
		if $c
		then 
			w3=`getColorCode ${words[3]}`
			w5=`getColorCode ${words[5]}`
		    echo -e "\033[01;38;5;${w3}m${words[3]}\033[00m \033[01;38;5;${w5}m${words[5]}\033[00m"
		fi
		;;
	*"- Light theme:"*)
		words=($l)
		#echo "color 1: ${words[3]}, color 2: ${words[5]}"
		;;
	esac
done < $refDir/TESTING.md

echo "Copy theme directory to $modDir where the modifications will happen."
cp -r $refDir $modDir

echo -e "\n\033[01;01mColors from _colors.scss\033[00m"
shellColors="/gnome-shell/src/gnome-shell-sass/_colors.scss"
refDarkBase="#000000"
refLightBase="#000000"
refDarkBg="#000000"
refLightBg="#000000"
refDarkFg="#000000"
refLightFg="#000000"

while read l; do
	words=($l)
	case $l in
	*'$base_color:'*)
		refDarkBase=${words[5]#*#}
		refDarkBase="#${refDarkBase:0:6}"
		refLightBase=${words[4]#*#}
		refLightBase="#${refLightBase:0:6}"
		;;
	*'$bg_color:'*)
		refDarkBg=${words[5]#*#}
		refDarkBg="#${refDarkBg:0:6}"
		refLightBg=${words[4]#*#}
		refLightBg="#${refLightBg:0:6}"
		;;
	*'$fg_color:'*)
		refDarkFg=${words[5]#*#}
		refDarkFg="#${refDarkFg:0:6}"
		refLightFg=${words[4]#*#}
		refLightF="#${refLightFg:0:6}"
		;;
	esac
done < $refDir$shellColors

displayColors () {
	codeLight=`getColorCode $2`
	codeDark=`getColorCode $3`
	echo "$1 \t \033[01;38;5;${codeLight}m$2\033[00m \033[01;38;5;${codeDark}m$3\033[00m"
}

echo -e '\t \t \t Light \t Dark'
echo -e `displayColors "Base \t \t" $refLightBase $refDarkBase`
echo -e `displayColors "Background \t" $refLightBg $refDarkBg`
echo -e `displayColors "Foreground \t" $refLightFg $refDarkFg`

echo -e "\n\033[01;01mColors from _pop_os_colors.scss\033[00m"
popOsColors="/gnome-shell/src/gnome-shell-sass/_pop_os_colors.scss"
refOrangeBL=#000000
refOrangeHL=#000000
refOrangeTL=#000000
refOrangeBD=#000000
refOrangeHD=#000000
refOrangeTD=#000000
refBlueBL=#000000
refBlueHL=#000000
refBlueTL=#000000
refBlueBD=#000000
refBlueHD=#000000
refBlueTD=#000000

ghpoc () {
	li=${1#*#}
	echo "#${li:0:6}"
}

while read l; do
	words=($l)
	case $l in
	*'$orange:'*)
		refOrangeBL=`ghpoc ${words[2]}`
		refOrangeBD=`ghpoc ${words[3]}`
		;;
	*'$highlights_orange:'*)
		refOrangeHL=`ghpoc ${words[2]}`
		refOrangeHD=`ghpoc ${words[3]}`
		;;
	*'$text_orange:'*)
		refOrangeTL=`ghpoc ${words[2]}`
		refOrangeTD=`ghpoc ${words[3]}`
		;;
	*'$blue:'*)
		refBlueBL=`ghpoc ${words[2]}`
		refBlueBD=`ghpoc ${words[3]}`
		;;
	*'$highlights_blue:'*)
		refBlueHL=`ghpoc ${words[2]}`
		refBlueHD=`ghpoc ${words[3]}`
		;;
	*'$text_blue:'*)
		refBlueTL=`ghpoc ${words[2]}`
		refBlueTD=`ghpoc ${words[3]}`
		;;
	esac
done < $refDir$popOsColors

echo -e '\t \t \t Light \t Dark'
echo -e `displayColors "Orange \t\t" $refOrangeBL $refOrangeBD`
echo -e `displayColors "Orange highlights" $refOrangeHL $refOrangeHD`
echo -e `displayColors "Orange text\t" $refOrangeTL $refOrangeTD`
echo -e `displayColors "Blue \t\t" $refBlueBL $refBlueBD`
echo -e `displayColors "Blue highlights" $refBlueHL $refBlueHD`
echo -e `displayColors "Blue text\t" $refBlueTL $refBlueTD`


