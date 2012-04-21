#!/bin/bash

#
# Android build script
#

#
# This is the main script for building a KANGed ROM for ICS
#
# If you don't know how to get or setup the ICS sources then here is one link that
# may help you get started
#   *** TODO: find the link
#
# Note that "ace" is referenced above, which is the codename for the Desire HD.
# Although this script *might* work for other phones it has only been tested for
# ACE builds.
#
# See init.sh for command line argument information.
#

# Returns the absolute path of the item which can be a file or directory
function GetAbsolutePath() {
  local ARG=$1
  local TEMP_BASE_NAME=`basename ${ARG}`
  local TEMP_DIR_NAME="$(cd "$(dirname "${ARG}")" && pwd)"

  if [ "$TEMP_BASE_NAME" != "." ]; then
    ARG=${TEMP_DIR_NAME}/${TEMP_BASE_NAME}
  else
    ARG=${TEMP_DIR_NAME}
  fi

  echo $ARG
}

# Returns the absolute directory for the given file
function GetAbsoluteDirOfFile() {
  local ARG=$1
  ARG="$(cd "$(dirname "${ARG}")" && pwd)"
  echo $ARG
}


# Error control
function ExitError() {
  echo ""
  ShowMessage "ERROR $@"
  echo ""
  exit 1
}

# Logged output
function ShowMessage() {
  echo "$@" | tee -a $LOG  2>&1
}

#
# Helper function for displaying a banner to indicate which step in the build is
# currently being done. Note that we can not use this until util_sh is loaded,
# which defines ShowMessage.
#
function banner() {
  ShowMessage ""
  ShowMessage "*******************************************************************************"
  ShowMessage "  $@"
  ShowMessage "*******************************************************************************"
  ShowMessage ""
}


# Get the UTC time in 2 formats
#  - UTC_DATE_STRING is a human readable string for display purposes
#  - UTC_DATE_FILE is the *same* date, but suitable for including in file names
# UTC_BASE_DATE is used to get the date to work with when creating the other 2
# dates. This was done so that there are no names for the day or month since if
# that is in a non-English language it might fail.
UTC_BASE_DATE=`date -u "+%F %T %Z"`
UTC_DATE_STRING=`date -u --date="${UTC_BASE_DATE}"`
UTC_DATE_FILE=`date -u --date="${UTC_BASE_DATE}" +%Y.%m.%d_%H.%M.%S_%Z`

# Get the full path of the directory that this script is running in.
THE_BUILD_DIR=`GetAbsoluteDirOfFile $0`

# Any included scripts are expected to be in the build_script directory below us.
THE_SCRIPT_DIR=${THE_BUILD_DIR}/build_scripts

# Any included patches are expected to be in the patches directory below us.
THE_PATCH_DIR=${THE_BUILD_DIR}/patches

# Setup a log file
LOG=${THE_BUILD_DIR}/build-${UTC_DATE_FILE}.log
export LOG

# Write a header to the LOG file. We don't use ShowMessage because we don't really
# want this to show up on the
echo "" > ${LOG}
echo "Date    : $UTC_DATE_STRING" >> ${LOG}
echo "Cmd Line: $0 $@" >> ${LOG}


# Process all the command line arguments before changing directory in case
# there are any relative paths.
source ${THE_SCRIPT_DIR}/init.sh || ExitError "Running 'build_scripts/init.sh'"

if [ $AB_RUN == "no" ]; then
  # Do not build anything. We just abort now that the build info has been displayed
  # by init.sh.
  exit 0
fi

# Do a clean if requested
if [ "$AB_CLEAN" = "yes" ]; then
  # *** TODO: Should this go into the build_xxx.sh script for each ROM?
  cd ${AB_SOURCE_DIR}

  banner "Cleaning ${AB_ROM_TYPE} (make clobber)"
  make clobber || ExitError "Doing ${AB_ROM_TYPE} clean, 'make clobber'"

  # After a clean we do not do the build
  exit 0
fi

# Do a 'repo sync' if requested
if [ "$AB_SYNC" = "yes" ]; then
  # *** TODO: Should this go into the build_xxx.sh script for each ROM?
  banner "${AB_ROM_TYPE} repo sync -j ${NUM_CPUS}"
  cd ${AB_SOURCE_DIR}
  repo sync -j ${NUM_CPUS} >> $LOG  || ExitError "Running ${AB_ROM_TYPE} 'repo sync'"
fi

#
# See if there are any GIT or DIFF patches to apply. We do not have to check
# FORCE_PATCHING here because that was used to determine whether or not to
# put patches on the ALL_PATCH_LIST. So if something is on the list we will do it.
#
if [ "$ALL_PATCH_LIST" != "" ]; then
  for PATCH_ITEM in $ALL_PATCH_LIST
  do
    PATCH_DIR=${PATCH_ITEM%%,*}
    PATCH_FILE=${PATCH_ITEM##*,}

    banner "Applying patch: ${PATCH_FILE}"
    if [ ! -d $PATCH_DIR ]; then
      ExitError "Patch file destination directory does not exist, '${PATCH_DIR}"
    fi

    # Change into the directory that the patch file needs to patch into.
    cd ${PATCH_DIR}

    if [ "${PATCH_FILE:(-4)}" = ".git" ]; then
      # .git patches are just like a shell script. Execute the patch.
      ShowMessage `cat $PATCH_FILE`
      $PATCH_FILE || ExitError "Applying patch file '$PATCH_FILE'"
    else
      # .patch patches are diff files
      patch --no-backup-if-mismatch -p0 < ${PATCH_FILE} || ExitError "Applying patch file '$PATCH_FILE'"
    fi

    cd - &>/dev/null
  done
fi


# Now do the build
source ${AB_ROM_SCRIPT} || ExitError "Running '${AB_ROM_SCRIPT}'"

#
# Copy results to Dropbox if requested
#
if [ "$AB_DROPBOX_DIR" != "" ] ; then
  banner "Copying files to Dropbox folder"

  ShowMessage "cp ${CM_NEW_ROM} ${AB_DROPBOX_DIR}"
  cp ${CM_NEW_ROM} ${AB_DROPBOX_DIR}
fi

#
# Decide whether or not to push the result to the phone
#
if [ "$AB_PUSH_TO_PHONE" = "yes" ] ; then
  banner "adb push ${CM_NEW_ROM} /sdcard/"
  adb push ${CM_NEW_ROM} /sdcard/ || ExitError "Pushing ROM to phone (is the phone attached?)"
fi

banner "Freshly cooked bacon is ready!"
ShowMessage "  ${AB_ROM_TYPE}:"
ShowMessage "    ROM = ${CM_NEW_ROM}"
ShowMessage "    MD5 = ${CM_NEW_ROM}.md5sum"
ShowMessage ""
