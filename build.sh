#!/bin/bash

#
# Android build script
#

#
# This is the main script for building a KANGed ROM for ICS
#
# If you don't know how to get or setup the ICS sources then here is one link that
# may help you get started
#   https://github.com/IceColdSandwich/android
#
# Note that "ace" is referenced above, which is the codename for the Desire HD.
# Although this script *might* work for other phones it has only been tested for
# ACE builds.
#
# See init.sh for command line argument information.
#

# We need to initialize a few variables so they function properly even before
# we load the .ini file.
AB_VERBOSE="1"

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

# Output wrapper in case we want to do something for each line of output.
function ShowMessage() {
  echo "$@"
}

# Error control
function ExitError() {
  ShowMessage ""
  ShowMessage "ERROR $@"
  ShowMessage ""
  exit 1
}

#
# Helper function for displaying a banner to indicate which step in the build is
# currently being done. Note that we can not use this until util_sh is loaded,
# which defines ShowMessage.
#
function Banner() {
  ShowMessage ""
  ShowMessage "*******************************************************************************"
  ShowMessage "  $@"
  ShowMessage "*******************************************************************************"
  ShowMessage ""
}

#
# Helper function to execute a command.
#  - arg 1 = command to execute
#  - arg 2 = message to give to Banner. "" = don't call Banner.
#  - arg 3 = message to give to ExitError if there is an error. "" = don't call ExitError.
#
function execute_cmd() {
  local cmd="$1"
  local msg="$2"
  local err="$3"

  if [ $AB_VERBOSE -ge 2 ]; then
    local dbg="execute_cmd(): cmd = \"${cmd}\", msg = \"${msg}\", err = \"${err}\""
    ShowMessage ""
    ShowMessage "${dbg}"
  fi

  if [ "$msg" != "" ]; then
    Banner ${msg}
  fi

  if [ "$err" == "" ]; then
    ${cmd}
  else
    ${cmd} || ExitError ${err}
  fi
}


# Get the UTC time in 2 formats
#  - UTC_DATE_STRING is a human readable string for display purposes
#  - UTC_DATE_FILE is the *same* date, but suitable for including in file names
# UTC_BASE_DATE is used to get the date to work with when creating the other 2
# dates. This was done so that there are no names for the day or month since if
# that is in a non-English language it might fail.
export UTC_BASE_DATE=`date -u "+%F %T %Z"`
export UTC_DATE_STRING=`date -u --date="${UTC_BASE_DATE}"`
export UTC_DATE_FILE=`date -u --date="${UTC_BASE_DATE}" +%Y.%m.%d_%H.%M.%S_%Z`

# Get the full path of the directory that this script is running in.
THE_BUILD_DIR=`GetAbsoluteDirOfFile $0`

# Any included scripts are expected to be in the build_script directory below us.
THE_SCRIPT_DIR=${THE_BUILD_DIR}/build_scripts

# Any included patches are expected to be in the patches directory below us.
THE_PATCH_DIR=${THE_BUILD_DIR}/patches

# We save all the command line arguments in a variable so we can still access
# them from within a function (because a function will have its own $@).
CMD_LINE_ARGS="$@"

# Process all the command line arguments before changing directory in case
# there are any relative paths. Many variables will be setup in init.sh.
execute_cmd "source ${THE_SCRIPT_DIR}/init.sh ${CMD_LINE_ARGS}"  "source ${THE_SCRIPT_DIR}/init.sh"  "Running source ${THE_SCRIPT_DIR}/init.sh"

if [ $AB_RUN == "no" ]; then
  # Do not build anything. We just abort now that the build info has been displayed
  # by init.sh.
  exit 0
fi

# Do a clean if requested
if [ "$AB_CLEAN" = "yes" ]; then
  # *** TODO: Should this go into the build_xxx.sh script for each ROM?
  cd ${AB_SOURCE_DIR}
  execute_cmd "make clobber"  "Cleaning ${AB_ROM_TYPE} (make clobber)"  "Running 'Cleaning ${AB_ROM_TYPE} (make clobber)'"

  # After a clean we do not do the build
  exit 0
fi

# Do a 'repo sync' if requested
if [ "$AB_SYNC" = "yes" ]; then
  # *** TODO: Should this go into the build_xxx.sh script for each ROM?
  cd ${AB_SOURCE_DIR}
  execute_cmd "repo sync -j ${NUM_CPUS}"  "repo sync -j ${NUM_CPUS}"  "Running 'repo sync -j ${NUM_CPUS}'"
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

    Banner "Applying patch: ${PATCH_FILE}"
    if [ ! -d $PATCH_DIR ]; then
      ExitError "Patch file destination directory does not exist, '${PATCH_DIR}"
    fi

    # Change into the directory that the patch file needs to patch into.
    cd ${PATCH_DIR}

    if [ "${PATCH_FILE:(-4)}" = ".git" ]; then
      # .git patches are just like a shell script. Execute the patch.
      ShowMessage `cat $PATCH_FILE`
      execute_cmd "${PATCH_FILE}"  ""  "Applying patch file '${PATCH_FILE}'"
    else
      # .patch patches are diff files
      execute_cmd "patch --no-backup-if-mismatch -p0 < ${PATCH_FILE}"  ""  "Applying patch file '${PATCH_FILE}'"
    fi

    cd - &>/dev/null
  done
fi


# Now do the build
execute_cmd "source ${AB_ROM_SCRIPT}"  "Running 'source ${AB_ROM_SCRIPT}'"  "Running 'source ${AB_ROM_SCRIPT}'"

#
# Copy results to Dropbox if requested
#
if [ "$AB_DROPBOX_DIR" != "" ] ; then
  Banner "Copying files to Dropbox folder"

  ShowMessage "cp ${AB_NEW_ROM} ${AB_DROPBOX_DIR}"
  cp ${AB_NEW_ROM} ${AB_DROPBOX_DIR}
fi

#
# Decide whether or not to push the result to the phone
#
if [ "$AB_PUSH_TO_PHONE" = "yes" ] ; then
  execute_cmd "adb push ${AB_NEW_ROM} /sdcard/"  "adb push ${AB_NEW_ROM} /sdcard/"  "Pushing ROM to phone (is the phone attached?)"
fi

if [ $AB_VERBOSE -ne 0 ]; then
  Banner "Freshly cooked bacon is ready!"
  ShowMessage "  ${AB_ROM_TYPE}:"
  ShowMessage "    ROM = ${AB_NEW_ROM}"
  ShowMessage "    MD5 = ${AB_NEW_ROM}.md5sum"
fi
ShowMessage ""
