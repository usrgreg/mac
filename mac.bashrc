
addpath() {
  ! [[ "$PATH" =~ "$1" ]] && export PATH=${1}:$PATH 
}

apkcpu() {
for i in $*
do
  echo "${i}	":`unzip -l "${i}" |grep lib/ |cut -d/ -f2 |sort -u`
done

}

apkname() {
for i in $*;do
  echo "$i	:"`aapt dump badging ${i} | awk '/package/{gsub("name=|'"'"'","");  print $2}'`
done
}

#rename file with space to _
mvspace() { 
find . -name "* *" -execdir bash -c 'mv "$0" "${0// /_}"' {} \;
}


rmqmark(){
  find . -name "*\?*" -execdir bash -c 'mv "$0" "${0%%\?*}"' {} \;
}

addpath "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/"
wifi(){
    if [[ -n $1 && (($1 == -l || --loop)) ]]; then
        clear
        while true; do 
            airport -I; 
            echo "Press Ctr+c to exit."; 
            sleep 1; 
            clear; 
        done 
    else
        airport -I;
        echo "\nPass -l or --loop for continous measurement"
    fi
}

alias l='ls -l'
alias ll='ls -rtl'
alias h=history



addpath ~/Library/Android/sdk/build-tools/34.0.0/

# to launch android virtual device
alias avd='/Users/gregsun/Library/Android/sdk/emulator/emulator -avd SuperTablet_API_29'
alias power='system_profiler SPPowerDataType'
