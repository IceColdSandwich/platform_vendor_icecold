#!/bin/bash

#
# build_ics.sh
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

if [ "$AB_MAKE_TYPE" == "full" ]; then
  banner "make clobber"
  make clobber >> $LOG || ExitError "Running 'make clobber'"

  banner "build/envsetup.sh && brunch ${AB_PHONE}"
  (source build/envsetup.sh && brunch ${AB_PHONE}) >> $LOG || ExitError "Running 'build/envsetup.sh && brunch ${AB_PHONE}'"

else
  if [ "$AB_MAKE_TYPE" == "rebuild" ]; then
    banner "build/envsetup.sh && breakfast ${AB_PHONE}"

    # Force build.prop to be recreated so that ro.build.date will always be updated
    # since this is viewable on "Settings-->About Phone" now.
    rm -f ${AB_SOURCE_DIR}/out/target/product/${AB_PHONE}/system/build.prop

    source build/envsetup.sh >> $LOG || ExitError "Running 'build/envsetup.sh'"
    breakfast ${AB_PHONE} >> $LOG || ExitError "Running 'breakfast ${AB_PHONE}'"

    # Making the bacon is the main build (MAX_CPUS was calculated in init.sh).
    banner "make bacon -j${MAX_CPUS}"
    make bacon -j${MAX_CPUS} >> $LOG || ExitError "Running 'make bacon'"
  else
    ExitError "Invalid value for AB_MAKE_TYPE, saw '${AB_MAKE_TYPE}'"
  fi
fi

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
  AB_NEW_ROM_BASE=${USER}-ics-${UTC_DATE_FILE}-RC.zip
else
  # Normal/nightly build
  AB_NEW_ROM_BASE=${USER}-ics-${UTC_DATE_FILE}.zip
fi
AB_NEW_ROM=${AB_OUT_ROM_DIR}/${AB_NEW_ROM_BASE}

rm -f ${AB_OUT_ROM_DIR}/${USER}-ics*.zip
rm -f ${AB_OUT_ROM_DIR}/${USER}-ics*.zip.md5sum
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


