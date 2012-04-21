#!/bin/bash

#
# build_cm7.sh
#
# This script is intended to be invoked from ../build.sh and requires various
# script variables to already be initialized. It is not intended to be invoked
# as a standalone script.
#

cd ${AB_SOURCE_DIR}

if [ "$CROSS_COMPILE" = "" ]; then
  export CROSS_COMPILE=${AB_SOURCE_DIR}/prebuilt/linux-x86/toolchain/arm-eabi-4.4.3/bin/arm-eabi-
fi
if [ "$TARGET_TOOLS_PREFIX" = "" ]; then
  export TARGET_TOOLS_PREFIX=${AB_SOURCE_DIR}/prebuilt/linux-x86/toolchain/arm-eabi-4.4.3/bin/arm-eabi-
fi
if [ "$ARCH" = "" ]; then
  export ARCH=arm
fi

if [ "$CCACHE_TOOL_DIR" = "" ] ; then
  CCACHE_TOOL_DIR=${AB_SOURCE_DIR}/prebuilt/linux-x86/ccache
  export PATH=$PATH:${CCACHE_TOOL_DIR}
fi

if [ "$CCACHE_DIR" = "" ] ; then
  CCACHE_DIR=${HOME}/.ccache
fi

##echo ""
##echo "CROSS_COMPILE       = '${CROSS_COMPILE}"
##echo "TARGET_TOOLS_PREFIX = '${TARGET_TOOLS_PREFIX}'"
##echo "ARCH                = '${ARCH}'"
##echo "CCACHE_TOOL         = '${CCACHE_TOOL_DIR}'"
##echo "CCACHE_DIR          = '${CCACHE_DIR}'"
##echo "PATH                = '${PATH}'"

# Output a newline since setting the cache size causes some output
echo ""
${CCACHE_TOOL_DIR}/ccache -M 10G


if [ "${AB_MAKE_TYPE}" = "full" ]; then
  banner "make clobber"
  make clobber >> $LOG || ExitError "Running 'make clobber'"

  banner "build/envsetup.sh && brunch ${AB_PHONE}"
  (source build/envsetup.sh && brunch ${AB_PHONE}) >> $LOG || ExitError "Running 'build/envsetup.sh && brunch ${AB_PHONE}'"

else
  if [ "${AB_MAKE_TYPE}" = "rebuild" ]; then
    banner "build/envsetup.sh && breakfast ${AB_PHONE}"

    # Force build.prop to be recreated so that ro.build.date will always be updated
    # since this is viewable on "Settings-->About Phone" now.
    rm -f ${AB_SOURCE_DIR}/out/target/product/${AB_PHONE}/system/build.prop

    source build/envsetup.sh >> $LOG || ExitError "Running 'build/envsetup.sh'"
    breakfast ${AB_PHONE} >> $LOG || ExitError "Running 'breakfast ${AB_PHONE}'"

    # Making the bacon is the main build (MAX_CPUS was calculated in init.sh).
    banner "make bacon -j ${MAX_CPUS}"
    make bacon -j ${MAX_CPUS} >> $LOG || ExitError "Running 'make bacon'"
  else
    ExitError "Invalid value for AB_MAKE_TYPE, saw '${AB_MAKE_TYPE}'"
  fi
fi

#
# NOTE: Any variables created from here down might be used by build.sh (our parent).
#       Changing them requires updating not only build.sh, but scripts for other ROMs.
#

#
# Rename the ROM to a date tagged name and clean up any old files that might be lying around.
#
CM_OLD_ROM=${OUT_ROM_DIR}/update-cm-*-signed.zip

# New ROM is what we rename it to.
# We also need the base name, mainly if building for BlackICE
CM_NEW_ROM_BASE=${USER}-cm7-${UTC_DATE_FILE}.zip
CM_NEW_ROM=${OUT_ROM_DIR}/${CM_NEW_ROM_BASE}

rm -f ${OUT_ROM_DIR}/${USER}-cm7*.zip
rm -f ${OUT_ROM_DIR}/${USER}-cm7*.zip.md5sum
rm -f ${OUT_ROM_DIR}/cyanogen_${AB_PHONE}-ota-eng*.zip

# Delete the md5sum file that the 'make' just created because it will contain
# the default Cyanogen name. We will recreate the md5sum next using the new ROM.
rm -f $CM_OLD_ROM.md5sum


mv $CM_OLD_ROM $CM_NEW_ROM

CM_MD5SUM=`md5sum -b $CM_NEW_ROM`
echo "${CM_MD5SUM}" > ${CM_NEW_ROM}.md5sum


if [ ! -e $CM_NEW_ROM ] ; then
  ExitError "Creating ${CM_NEW_ROM}"
fi

if [ ! -e ${CM_NEW_ROM}.md5sum ] ; then
  ExitError "Creating ${CM_NEW_ROM}.md5sum"
fi

return 0


