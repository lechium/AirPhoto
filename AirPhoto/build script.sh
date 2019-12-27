# this script was only possible because of Dustin Howetts epic theos project, thanks Dustin :)

# we need to export this path because dpkg-deb is usually installed via macports

export PATH=/opt/local/bin:/opt/local/sbin:/usr/local/git:$PATH
export SRCROOT="$SRCROOT"
CODEROOT="$SRCROOT"/"$PRODUCT_NAME"
ENT="$CODEROOT"/ent.plist

#echo $SRCROOT
#echo $ENT
#echo $SDKROOT

BASE_SDK=`basename $SDKROOT`
if [[ $BASE_SDK == *"Simulator"* ]]
then
    exit 0
fi

# only used if we SCP the deb over, and this only happens if dpkg-deb and fauxsu are installed

ATV_DEVICE_IP=guest-room.local

# xcodes path to the the full application

TARGET_BUILD_APPLICATION="$TARGET_BUILD_DIR"/"$PRODUCT_NAME".$WRAPPER_EXTENSION

# our layout dir and control file

LAYOUT="$CODEROOT"/layout
CONTROL_FILE="$LAYOUT"/DEBIAN/control

#echo $LAYOUT
#echo $CONTROL_FILE

# only needed if you have any mobile subtrate plugins involved, this may be taken care of by post scripts in theos, where its still the easiest to build ms tweaks

SUBSTRATE_LAYOUT_PATH="$LAYOUT"/Library/MobileSubstrate/DynamicLibraries

# build directory for theos, we're still following his format and style as closely as possible

DPKG_BUILD_PATH="$CODEROOT"/_

# DEBIAN location in the staging / build directory

DPKG_DEBIAN_PATH="$DPKG_BUILD_PATH"/DEBIAN

APPLETV_APPLICATION_FOLDER="$DPKG_BUILD_PATH/Applications"

# final application location in the staging directory

FINAL_APP_PATH="$APPLETV_APPLICATION_FOLDER/$PRODUCT_NAME.$WRAPPER_EXTENSION"

echo "FINAL APP PATH: $FINAL_APP_PATH"

# paths for the applications

mkdir -p "$APPLETV_APPLICATION_FOLDER"

# make sure these are all there

mkdir -p "$DPKG_BUILD_PATH"

mkdir -p "$DPKG_DEBIAN_PATH"

# for this particular project we dont need this directory, but if you have ms tweaks involved you will want to comment this back in

#mkdir -p $SUBSTRATE_LAYOUT_PATH

# plucked from package.mk in theos/makesfiles lines 39-41 and adapted for shell/bash script

CONTROL_PACKAGE_NAME=`cat "$PRODUCT_NAME"/layout/DEBIAN/control | grep "^Package:" | cut -d' ' -f2-`
CONTROL_PACKAGE_ARCH=`cat "$PRODUCT_NAME"/layout/DEBIAN/control | grep "^Architecture:" | cut -d' ' -f2-`
CONTROL_PACKAGE_BASE_VERSION=`cat "$PRODUCT_NAME"/layout/DEBIAN/control | grep "^Version:" | cut -d' ' -f2-`

# i dont quite understand his fakeroot stuff so im just looking for a path to fauxsu

FAUXSU_PATH=`which fakeroot`

# we need dpkg-deb to make the package, this is the easiest way i can think of to find its location.

DPKG_DEB_PATH=`which dpkg-deb`

#CODE_SIGN_ENTITLEMENTS
#EXECUTABLE_NAME

echo $EXECUTABLE_PATH
echo $CODE_SIGN_ENTITLEMENTS

#echo $FINAL_APP_PATH

for DYLIB in `find "$FINAL_APP_PATH" -name '*.dylib'`; do

echo $DYLIB

LDIDS="jtool --sign platform --ent $ENT $DYLIB --inplace"

echo $LDIDS

jtool --sign platform --ent $ENT $DYLIB --inplace

done

if [ -d "$FINAL_APP_PATH/Frameworks" ]; then

for FW in `find "$FINAL_APP_PATH/Frameworks" -name '*.framework'`; do


#name=${i%\.*}

EXE=`plutil -extract CFBundleExecutable xml1  "$FW"/Info.plist -o - | grep "<string>" | sed 's/<*string>//g' | sed 's|</||'`


LDIDS="jtool --sign platform --ent $ENT "$FW/$EXE" --inplace"

echo $LDIDS

#ldid -S "$FW/$EXE"

jtool --sign platform --ent $ENT "$FW/$EXE" --inplace


#ldid -S $name

done

fi

if [ -d "$FINAL_APP_PATH/PlugIns" ]; then

for PLUGIN in `find "$FINAL_APP_PATH/PlugIns" -name '*.appex'`; do

EXE=`plutil -extract CFBundleExecutable xml1  "$PLUGIN"/Info.plist -o - | grep "<string>" | sed 's/<*string>//g' | sed 's|</||'`


#ldid -e "$PLUGIN/$EXE" > /tmp/ent.plist
#cat /tmp/ent.plist
#LDIDS="ldid -S/tmp/ent.plist $PLUGIN/$EXE"
#echo $LDIDS
#ldid -S/tmp/ent.plist "$PLUGIN/$EXE"
#rm /tmp/ent.plist

LDIDS="jtool --sign platform --ent $ENT "$PLUGIN/$EXE" --inplace"
echo $LDIDS

jtool --sign platform --ent $ENT "$PLUGIN/$EXE" --inplace

done
fi
#for INFO in `find "$FINAL_APP_PATH" -name 'Info.plist'`; do

EXE=`plutil -extract CFBundleExecutable xml1 "$FINAL_APP_PATH/Info.plist" -o - | grep "<string>" | sed 's/<*string>//g' | sed 's|</||'`


LDIDS="jtool --sign platform --ent $ENT $FINAL_APP_PATH/$EXE --inplace"
echo $LDIDS
jtool --sign platform --ent $ENT $FINAL_APP_PATH/$EXE --inplace

#LDIDS="ldid -S/tmp/ent.plist $FINAL_APP_PATH/$EXE"
#echo $LDIDS
#ldid -e "$FINAL_APP_PATH/$EXE" > /tmp/ent.plist
#cat /tmp/ent.plist
#ldid -S/tmp/ent.plist "$FINAL_APP_PATH/$EXE"
#rm /tmp/ent.plist
#done

# plucked and modified from theos/makesfiles/pacakge.mk as well, 46 - 56 (im including the $FINAL_PACKAGE_DEBVERSION code further down as well)
# the first rsync command is syncing the layout folder with the _ folder, the second is syncing the frappliance into its final staging destination

rsync -a "$LAYOUT"/ "$DPKG_BUILD_PATH"/ --exclude "_MTN" --exclude ".git" --exclude ".svn" --exclude ".DS_Store" --exclude "._*" --exclude "/.Spotlight-V100" --exclude "/.Trashes"
rsync -a "$TARGET_BUILD_APPLICATION"/ "$FINAL_APP_PATH"/ --exclude "_MTN" --exclude ".git" --exclude ".svn" --exclude ".DS_Store" --exclude "._*" --exclude "/.Spotlight-V100" --exclude "/.Trashes"


# had to move SIZE down because the size would've been for the prior build and not the current because it was run before rsync steps, thanks again Dustin !!

PWD=`pwd`
echo $PWD

SIZE=`du -I DEBIAN -ks "$PRODUCT_NAME"/_ | cut -f 1`

echo $SIZE

# package_v.sh is nearly identical to the one in theos/bin with basically one variable swapped with $SRCROOT, one line cant describe the awesomness of that script.

# short and skinny it checks the base version of the layout control file and compares it against the .theos/packages/ folder information to find the next proper build number
# and it writes a new control file with the proper Version: into the staging DEBIAN directory

"$CODEROOT"/package_v.sh -c ${CONTROL_FILE} > "$DPKG_DEBIAN_PATH"/control

# adding Installed-Size: to the final DEBIAN/control file

echo "Installed-Size: $SIZE" >> "$DPKG_DEBIAN_PATH"/control

# pluck out this version we just slipped into the new control file for purposes of the end deb package name

FINAL_PACKAGE_DEBVERSION=`cat "$DPKG_DEBIAN_PATH"/control | grep "^Version:"| cut -d' ' -f2`

# the big enchirido, the full package name in all its glory

FILENAME="$CONTROL_PACKAGE_NAME"_"$FINAL_PACKAGE_DEBVERSION"_"$CONTROL_PACKAGE_ARCH".deb

echo "$FILENAME"

if [ -f "$DPKG_DEB_PATH" ]; then
echo "we have dpkg-deb too!"
"$FAUXSU_PATH" "$DPKG_DEB_PATH" -b "$DPKG_BUILD_PATH" "$SRCROOT"/"$FILENAME"

echo "$FAUXSU_PATH" "$DPKG_DEB_PATH" -b "$DPKG_BUILD_PATH" "$SRCROOT"/"$FILENAME"

# these lines were plucked from the theos/bin/install.exec and theos/bin/install.copyFile

# scp the deb over into ~

scp -P 22 "$SRCROOT"/"$FILENAME" root@$ATV_DEVICE_IP:~

# install the dpkg

ssh -p 22 root@$ATV_DEVICE_IP "export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/X11:/usr/games ; /usr/bin/dpkg -i $FILENAME"

# restart Lowtide/AppleTV.app

ssh -p 22 root@$ATV_DEVICE_IP "/usr/bin/uicache"

# done and done!

else # DPKG_DEB_PATH check

echo "You need dpkg-deb installed to create the deb packages, homebrew is recommended for easiest and quickest installation!!"

fi



