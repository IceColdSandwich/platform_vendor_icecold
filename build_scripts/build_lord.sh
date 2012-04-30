#!/bin/bash

#
# build_lord.sh
#
# This script is intended to be invoked from ../build.sh and requires various
# script variables to already be initialized. It is not intended to be invoked
# as a standalone script.
#

cd ${AB_SOURCE_DIR}

if [ "$CROSS_COMPILE" == "" ]; then
  export CROSS_COMPILE=${AB_SOURCE_DIR}/prebuilt/linux-x86/toolchain/arm-eabi-4.6.3/bin/arm-linux-androideabi-
fi
if [ "$TARGET_TOOLS_PREFIX" == "" ]; then
  export TARGET_TOOLS_PREFIX=${AB_SOURCE_DIR}/prebuilt/linux-x86/toolchain/arm-eabi-4.6.3/bin/arm-linux-androideabi-
fi
if [ "$ARCH" == "" ]; then
  export ARCH=arm
fi

if [ "$CCACHE_TOOL_DIR" == "" ] ; then
  CCACHE_TOOL_DIR=${AB_SOURCE_DIR}/prebuilt/linux-x86/ccache
  export PATH=$PATH:${CCACHE_TOOL_DIR}
fi

if [ "$CCACHE_DIR" == "" ] ; then
  CCACHE_DIR=${HOME}/.ccache
fi

# Output a newline so that the output from setting the cache size looks better.
echo ""
${CCACHE_TOOL_DIR}/ccache -M 20G

# This is a bit of a hack, but we need AB_PHONE to be a normal phone name like 'ace';
# However, this source's make files require a modified version of that name.
#LC_PHONE=htc_${AB_PHONE}-eng
LC_PHONE=htc_${AB_PHONE}-userdebug

# Force build.prop to be recreated so that ro.build.date will always be updated
# since this is viewable on "Settings-->About Phone" now.
rm -f ${AB_SOURCE_DIR}/out/target/product/${AB_PHONE}/system/build.prop

if [ "$AB_MAKE_TYPE" == "full" ]; then
  banner "make clobber"
  make clobber >> $LOG || ExitError "Running 'make clobber'"
fi

banner "build/envsetup.sh && lunch ${LC_PHONE}"
source build/envsetup.sh >> $LOG || ExitError "Running 'build/envsetup.sh'"
lunch ${LC_PHONE} >> $LOG || ExitError "Running 'lunch ${LC_PHONE}'"

# Making the bacon is the main build (MAX_CPUS was calculated in init.sh).
banner "make lord -j${MAX_CPUS}"
make lord -j${MAX_CPUS} >> $LOG || ExitError "Running 'make lord'"

#
# NOTE: Any variables created from here down might be used by build.sh (our parent).
#       Changing them requires updating not only build.sh, but scripts for other ROMs.
#

# AB_OUT_ROM_DIR needs to match the location used by the sourc code's Makefile.
AB_OUT_ROM_DIR=${AB_SOURCE_DIR}/out/target/product/${AB_PHONE}
AB_OLD_ROM=${AB_OUT_ROM_DIR}/IceColdSandwich-*-signed.zip

# Create the name for the new ROM file as well as a full path to it. We don't
# really need a separate AB_NEW_ROM_BASE variable right now, but we might want
# to have it around in the future.
#
if [ "$AB_OFFICIAL" == "yes" ]; then
  # Release candidate build (official build)
  AB_NEW_ROM_BASE=${USER}-lc-ics-${UTC_DATE_FILE}-RC.zip
else
  # Normal/nightly build
  AB_NEW_ROM_BASE=${USER}-lc-ics-${UTC_DATE_FILE}.zip
fi
AB_NEW_ROM=${AB_OUT_ROM_DIR}/${AB_NEW_ROM_BASE}

rm -f ${AB_OUT_ROM_DIR}/${USER}-lc-ics*.zip
rm -f ${AB_OUT_ROM_DIR}/${USER}-lc-ics*.zip.md5sum
rm -f ${AB_OUT_ROM_DIR}/htc_ace-ota-eng*.zip


# Delete the md5sum file that the 'make' just created because it will contain
# the default Cyanogen name. We will recreate the md5sum next using the new ROM.
rm -f ${AB_OLD_ROM}.md5sum


mv ${AB_OLD_ROM} ${AB_NEW_ROM}

AB_MD5SUM=`md5sum -b ${AB_NEW_ROM}`
echo "${AB_MD5SUM}" > ${AB_NEW_ROM}.md5sum


if [ ! -e $AB_NEW_ROM ] ; then
  ExitError "Creating ${AB_NEW_ROM}"
fi

if [ ! -e ${AB_NEW_ROM}.md5sum ] ; then
  ExitError "Creating ${AB_NEW_ROM}.md5sum"
fi

return 0


