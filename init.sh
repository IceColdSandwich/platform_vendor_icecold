#!/bin/bash

#
# init.sh
#

# The prefix 'AB_' for the variables stands for Android Build

#
# Command line arguments:
#
#  -ini <ini_file>
#     Specifies the .ini file to load, which defines the script variables needed.
#     It's a good idea to specify this so you don't have to enter a LOT of options
#     on the command line!
#
#  -clean {0, no, "", 1, yes}
#     0, no, "" = do not do a clean before building
#     1, yes    = do a 'make clobber' before building
#     If a clean is specified then nothing will be built and most other arguments
#     will be ignored.
#     Affects the variable AB_CLEAN
#
#  -verbose {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}
#     0    = extra quite build messages (may not be implemented).
#     1    = normal build messages.
#     2    = additional build messages.
#     3..9 = even more build messages (may not be implemented yet)
#     Affects the variable AB_VERBOSE
#
#  -rom {cm7, ics, lord, ...}
#     Determines the type of build and invokes a child build script using this
#     value as part of the name. For example, 'cm7' would invoke build_cm7.sh.
#     cm7   = build a CM7 ROM.
#     ics   = build an ICS ROM.
#     lord  = build a LorDClockaN version of ICS
#     Affects the variable AB_ROM_TYPE
#
#  -sync {0, no, "", 1, yes}
#     0, no, "" = no sync
#     1, yes    = do a 'repo sync' before building
#     Affects the variable AB_SYNC
#
#  -synccpus = n
#     n < 0 = CPUs to use during sync = max - n (result must be > 0)
#     0     = Use all CPUs during sync
#     n > 0 = Use n CPUs during sync (n must be <= max)
#     Affects the variable AB_SYNC_CPUS
#
#  -fpatch {0, no, "", 1, yes}
#     0, no, "" = do not force patches to be applied when not syncing (default and suggested)
#     1, yes    = force patches to be applied when not syncing (not recommended)
#     Normally you do not want to enable this becuase patching an already patched
#     code base will cause an error and the build will abort. This is mainly here
#     in case you did a manual sync and then decide to build and you want the normal
#     patches to be applied.
#     Affects the variable AB_FORCE_PATCHING
#
#  -push {0, no, "", 1, yes}
#     0, no, "" = do not 'adb push' the resulting KANG to your phone
#     1, yes    = 'adb push' the resulting KANG  to your phone, requires your phone
#                 to be connected to your PC via USB and the 'adb' tool in your path.
#     Affects the variable AB_PUSH_TO_PHONE
#
#  -phone <phone name>
#     ace = build for ACE (Desire HD). Building for other phones *might* work,
#           but this has not been tested!
#     Affects the variable AB_PHONE
#
#  -sourcedir <source path>
#     Root directory where your ROM sources are installed, for example:
#       ${HOME}/android/system
#     Affects the variable AB_SOURCE_DIR
#
#  -dbox <dropbox path>
#     Directory of your dropbox (or a sub-directory inside of it) to copy the
#     result files to, for example:
#       ${HOME}/Dropbox  -- or -- ${HOME}/Dropbox/Public/MyRoms
#     This gets the upload started as soon as possible.
#     If this is an empty value, "", then nothing is copied to the dropbox.
#     Affects the variable AB_DROPBOX_DIR
#
#  -make {full, rebuild}
#     This specifies what type of build to do.
#       full    = do 'make clobber' and then 'source build/envsetup.sh ' and then a rebuild.
#       rebuild = just do a rebuild, which varies depending on the ROM, for example
#                   - bacon = make bacon (e.g. for CM7)
#                   - lunch = make lunch
#                   - lord  = make lord  (e.g. for LorDClockaN's ICS)
#                 This requires that a previous full ROM build was done since these
#                 processes assume certain things are already pre-built.
#     Affects the variable AB_MAKE_TYPE
#
#  -run {0, no, "", 1, yes}
#     Determines whether we actually start the build or just display the build info.
#     It's better for this to be 'no' so you can look at what is going to be done without
#     doing it. Then if everything is OK do the same command line, but add '-run yes'.
#     "", 0, no = display build information but do not build anything.
#     1, yes    = display build information and then do the buiod.
#     Affects the variable AB_RUN
#
#  -official {0, no, "", 1, yes}
#     "", 0, no = normal build (nightly)
#     1, yes    = release build (adds '-RC' to the ROM name).
#     Affects the variable AB_OFFICIAL
#

#
# Examples:
#   build.sh -ini custom.ini
#     - Initialize all the variables from the file 'custom.ini'
#     - The actions taken will depend on the variable definitions.
#
#   build.sh -ini build_cm7.ini -sync no -run yes
#     - Initialize all the variables from the file 'build_cm7.ini'
#     - Build a CM7 KANG without doing a repo sync.
#     - The result is pushed to the phone (assuming thi .ini file hasn't been modified).
#     - The '-run yes' causes the build to occur.
#     - Other options come from the .ini file.
#
#   build.sh -ini build_lord.ini -run no
#     - Initialize all the variables from the file 'build_lord.ini'
#     - We've chosen the LorDClockaN version of ICS.
#     - Because of '-run no' the build informations is shown, but nothing is built.
#     - Other options come from the .ini file.
#

# Helper to check yes/no options. We return: 'no', 'yes' or on error the original value
function checkYesNoOption() {
  local RESULT="$1"

  if  [ "$1" == "" ] || [ "$1" == "0" ] || [ "$1" == "no" ]; then
    RESULT="no"
  else
    if [ "$1" == "1" ] || [ "$1" == "yes" ] ; then
      RESULT="yes"
    fi
  fi

  echo "${RESULT}"
}


if [ "$USER" == "" ] || [ "$HOME" == "" ] ; then
  echo ""
  echo "$0: The Linux environment variables USER and HOME must be defined!"
  echo ""
  return 1
fi

#
# Stores the .ini file name for display and also so we can detect if it was given
INI_NAME=""

# Will hold the name of the build script as determined by AB_ROM_TYPE
AB_ROM_SCRIPT=""

# SHOW_HELP will let us decide if we need to display the usage information
SHOW_HELP=0

#
# We don't check for errors in this loop except for not being able to find the .ini
# file. Instead we wait until we are done so we can detect errors that occur becuase
# of either the .ini file or the command line.
#
while [ $# -gt 0 ] && [ "$SHOW_HELP" == "0" ]; do
  # We need to set this to 1 every time in order to detect a bad option.
  SHOW_HELP=1

  if [ "$1" == "-h" ] || [ "$1" == "-?" ] || [ "$1" == "-help" ]; then
    SHOW_HELP=2
    break
    # Exit the loop so that we avoid the 'Invalid option' error.
  fi

  if [ "$1" == "-ini" ]; then
    shift 1
    INI_NAME=$1

    # Check for leading "-", which indicates we got another command line option
    # instead of an ini name.
    ARG_TEMP=${INI_NAME:0:1}
    if [ "$INI_NAME" == "" ] || [ "${INI_NAME:0:1}" == "-" ]; then
      echo ""
      echo "  ERROR: Expected a file name after '-ini', saw '${INI_NAME}'"
      echo ""

      # Exit the loop so that we avoid the 'Invalid option' error.
      break
    else
      if [ "${INI_NAME:0:1}" != "/" ] && [ "${INI_NAME:0:1}" != "." ]; then
        if [ -f ${THE_SCRIPT_DIR}/${INI_NAME} ]; then
          INI_NAME=${THE_SCRIPT_DIR}/${INI_NAME}
        fi
      fi

      INI_NAME=`GetAbsolutePath ${INI_NAME}`
      if [ ! -f $INI_NAME ]; then
        echo ""
        echo "  ERROR .ini file '${INI_NAME}' does not exist"
        echo ""

        # Exit the loop so that we avoid the 'Invalid option' error.
        break
      else
        source ${INI_NAME}
        RESULT="$?"
        if [ "$RESULT" != "0" ] ; then
          echo ""
          echo "  ERROR processing '${INI_NAME}' = ${RESULT}"
          echo ""

          # Exit the loop so that we avoid the 'Invalid option' error.
          break
        else
          SHOW_HELP=0
        fi
      fi
    fi
  fi

  if [ "$1" == "-verbose" ]; then
    shift 1
    AB_VERBOSE=$1
    SHOW_HELP=0
  fi

  if [ "$1" == "-clean" ]; then
    shift 1
    AB_CLEAN=$1
    SHOW_HELP=0
  fi

  if [ "$1" == "-rom" ]; then
    shift 1
    AB_ROM_TYPE=$1
    SHOW_HELP=0
  fi

  if [ "$1" == "-sync" ]; then
    shift 1
    AB_SYNC=$1
    SHOW_HELP=0
  fi

  if [ "$1" == "-synccpus" ]; then
    shift 1
    AB_SYNC_CPUS=$1
    SHOW_HELP=0
  fi

  if [ "$1" == "-push" ]; then
    shift 1
    AB_PUSH_TO_PHONE=$1
    SHOW_HELP=0
  fi

  if [ "$1" == "-fpatch" ]; then
    shift 1
    AB_FORCE_PATCHING=$1
    SHOW_HELP=0
  fi

  if [ "$1" == "-phone" ]; then
    shift 1
    AB_PHONE=$1
    SHOW_HELP=0
  fi

  if [ "$1" == "-srcdir" ]; then
    shift 1
    AB_SOURCE_DIR=$1
    SHOW_HELP=0
  fi


  if [ "$1" == "-dbox" ]; then
    shift 1
    AB_DROPBOX_DIR=$1
    SHOW_HELP=0
  fi

  if [ "$1" == "-make" ]; then
    shift 1
    AB_MAKE_TYPE=$1
    SHOW_HELP=0
  fi

  if [ "$1" == "-run" ]; then
    shift 1
    AB_RUN=$1
    SHOW_HELP=0
  fi

  if [ "$1" == "-official" ]; then
    shift 1
    AB_OFFICIAL=$1
    SHOW_HELP=0
  fi

  if [ "$SHOW_HELP" != "0" ]; then
    echo ""
    echo "  ERROR: Invalid option, saw '${1}'"
    echo ""
    break;
  fi

  shift 1
done

#
# Now that we got all the command line parameters, verify the variables. We do this
# now instead of in the command parser so that we also verify the values of
# variables that come from the .ini file in case someone made a typo in there.
#
if [ "$SHOW_HELP" == "0" ]; then

  if [ "$AB_VERBOSE" == "" ]; then
    AB_VERBOSE=1
  fi
  if [ $AB_VERBOSE -lt 0 -o $AB_VERBOSE -gt 9 ]; then
    echo ""
    echo "  ERROR: Valid values for AB_VERBOSE (in .ini file) or '-verbose' are {0..9}, saw '${AB_VERBOSE}'"
    echo ""
    SHOW_HELP=1
  fi

  AB_CLEAN=`checkYesNoOption ${AB_CLEAN}`
  if  [ "$AB_CLEAN" != "no" ] && [ "$AB_CLEAN" != "yes" ]; then
    echo ""
    echo "  ERROR: Valid values for AB_CLEAN (in .ini file) or '-clean' are {0, no, \"\", 1, yes}, saw '${AB_CLEAN}'"
    echo ""
    SHOW_HELP=1
  fi

  if  [ "$AB_CLEAN" == "no" ]; then
    # We aren't doing a clean, so we need to validate EVERYTHING.

    AB_ROM_SCRIPT=${THE_SCRIPT_DIR}/build_${AB_ROM_TYPE}.sh
    if [ "$AB_ROM_TYPE" == "" ] || [ ! -f ${AB_ROM_SCRIPT} ]; then
      ROM_CHOICES=""
      TEMP_FILES=${THE_SCRIPT_DIR}/build_*.sh
      for f in $TEMP_FILES
      do
        f=${f##*build_}   # Delete everything up to and including 'build_" from the start of the name
        f=${f%.sh}        # Delete ".sh" from the end of the name
        ROM_CHOICES=${ROM_CHOICES}"${f} "
      done

      echo ""
      echo "  ERROR: Valid values for AB_ROM_TYPE (in .ini file) or '-rom' are {${ROM_CHOICES}}, saw '${AB_ROM_TYPE}'"
      echo ""
      SHOW_HELP=1
    fi

    AB_SYNC=`checkYesNoOption ${AB_SYNC}`
    if  [ "$AB_SYNC" != "no" ] && [ "$AB_SYNC" != "yes" ]; then
      echo ""
      echo "  ERROR: Valid values for AB_SYNC (in .ini file) or '-sync' are {0, no, \"\", 1, yes}, saw '${AB_SYNC}'"
      echo ""
      SHOW_HELP=1
    fi

    MAX_CPUS=`grep -c processor /proc/cpuinfo`
    MIN_CPUS=$(( 1 - MAX_CPUS ))
    if [ "$AB_SYNC_CPUS" == "" ] || ! [[ "$AB_SYNC_CPUS" =~ ^-?[0-9]+$ ]]; then
      echo ""
      echo "  ERROR: AB_SYNC_CPUS (in .ini file) or '-synccpus' must be a number, saw '${AB_SYNC_CPUS}'"
      echo ""
      SHOW_HELP=1
    else
      if [ "$AB_SYNC_CPUS" -eq "0" ]; then
        NUM_CPUS=$MAX_CPUS
      else
        if [ "$AB_SYNC_CPUS" -lt "0" ]; then
          # Use '+' here because AB_SYNC_CPUS is negative!
          NUM_CPUS=$(( MAX_CPUS + AB_SYNC_CPUS))
        else
          NUM_CPUS=$AB_SYNC_CPUS
        fi
      fi

      # We don't prevent someone from specifying more CPUs than they have.
      if [ "$NUM_CPUS" -lt "$MIN_CPUS" ] || [ "$NUM_CPUS" -eq "0" ]; then
        echo ""
        echo "  ERROR: AB_SYNC_CPUS (in .ini file) or '-synccpus' value results in an invalid number: '${AB_SYNC_CPUS}' --> '${NUM_CPUS}'"
        echo ""
        SHOW_HELP=1
      fi
    fi

    AB_PUSH_TO_PHONE=`checkYesNoOption ${AB_PUSH_TO_PHONE}`
    if  [ "$AB_PUSH_TO_PHONE" != "no" ] && [ "$AB_PUSH_TO_PHONE" != "yes" ]; then
      echo ""
      echo "  ERROR: Valid values for AB_PUSH_TO_PHONE (in .ini file) or '-push' are {0, no, \"\", 1, yes}, saw '${AB_PUSH_TO_PHONE}'"
      echo ""
      SHOW_HELP=1
    fi

    AB_OFFICIAL=`checkYesNoOption ${AB_OFFICIAL}`
    if  [ "$AB_OFFICIAL" != "no" ] && [ "$AB_OFFICIAL" != "yes" ]; then
      echo ""
      echo "  ERROR: Valid values for AB_OFFICIAL (in .ini file) or '-official' are {0, no, \"\", 1, yes}, saw '${AB_OFFICIAL}'"
      echo ""
      SHOW_HELP=1
    fi

    AB_FORCE_PATCHING=`checkYesNoOption ${AB_FORCE_PATCHING}`
    if  [ "$AB_FORCE_PATCHING" != "no" ] && [ "$AB_FORCE_PATCHING" != "yes" ]; then
      echo ""
      echo "  ERROR: Valid values for AB_FORCE_PATCHING (in .ini file) or '-fpatch' are {0, no, \"\", 1, yes}, saw '${AB_FORCE_PATCHING}'"
      echo ""
      SHOW_HELP=1
    fi

    # A leading "-" indicates we got another command line option instead of a phone name.
    ARG_TEMP=${AB_PHONE:0:1}
    if [ "$AB_PHONE" == "" ] || [ "$ARG_TEMP" == "-" ]; then
      echo ""
      echo "  ERROR: Invalid value for AB_PHONE (in .ini file) or '-phone', saw '${AB_PHONE}'"
      echo ""
      SHOW_HELP=1
    fi

    if [ "$AB_MAKE_TYPE" == "" ] || ([ "$AB_MAKE_TYPE" != "full" ] && [ "$AB_MAKE_TYPE" != "rebuild" ]); then
      echo ""
      echo "  ERROR: Valid values fo AB_MAKE_TYPE (in .ini file) or '-make' are {full, rebuild}, saw '${AB_MAKE_TYPE}'"
      echo ""
      SHOW_HELP=1
    fi

    # A leading "-" indicates we got another command line option instead of a phone name.
    if [ "$AB_DROPBOX_DIR" != "" ]; then
      ARG_TEMP=${AB_DROPBOX_DIR:0:1}
      if [ "$ARG_TEMP" == "-" ]; then
        echo ""
        echo "  ERROR: Invalid value for AB_DROPBOX_DIR (in .ini file) or '-dbox', saw '${AB_DROPBOX_DIR}'"
        echo ""
        SHOW_HELP=1
      else
        AB_DROPBOX_DIR=`GetAbsolutePath ${AB_DROPBOX_DIR}`
        if [ ! -d $AB_DROPBOX_DIR ]; then
          echo ""
          echo "  ERROR: AB_DROPBOX_DIR does not exist: '${AB_DROPBOX_DIR}'"
          echo ""
          SHOW_HELP=1
        fi
      fi
    fi
  fi      # End of items skipped when CLEAN_ONLY is "1"

  #
  # These items need to be checked even if just doing a clean
  #

  AB_RUN=`checkYesNoOption ${AB_RUN}`
  if  [ "$AB_RUN" != "no" ] && [ "$AB_RUN" != "yes" ]; then
    echo ""
    echo "  ERROR: Valid values for AB_RUN (in .ini file) or '-run' are {0, no, \"\", 1, yes}, saw '${AB_RUN}'"
    echo ""
    SHOW_HELP=1
  fi

  # A leading "-" indicates we got another command line option instead of a directory name.
  ARG_TEMP=${AB_SOURCE_DIR:0:1}
  if [ "$AB_SOURCE_DIR" == "" ] || [ "$AB_SOURCE_DIR" == "-" ]; then
    echo ""
    echo "  ERROR: Invalid value for AB_SOURCE_DIR (in .ini file) or '-srcdir', saw '${AB_SOURCE_DIR}'"
    echo ""
    SHOW_HELP=1
  else
    AB_SOURCE_DIR=`GetAbsolutePath ${AB_SOURCE_DIR}`
    if [ ! -d $AB_SOURCE_DIR ]; then
      echo ""
      echo "  ERROR: AB_SOURCE_DIR does not exist: '${AB_SOURCE_DIR}'"
      echo ""
      SHOW_HELP=1
    fi
  fi
fi

if [ "$SHOW_HELP" -gt "0" ]; then
  if [ "$SHOW_HELP" == "1" ]; then
    echo "  For more details use the command line option '-help' and see the"
    echo "  comments in the top of '$0' and build_scripts/init.sh"
    echo ""
  else
    echo ""
    echo "  Usage is $0 [params]"
    echo "    -ini <ini_file>"
    echo "       specifies the .ini file to load, which specifies most other options."
    echo "    -clean {0, no, \"\", 1, yes}"
    echo "       Specifies whether or not to do a clean. Depending on the ROM this"
    echo "       might be a 'make clean' or 'make clobber' or ???."
    echo "       If any clean is specified then we do not build anything."
    echo "    -verbose {0..9}"
    echo "       0 = extra quite (not implemented), 1 = normal build messages,"
    echo "       2 = extra build messages, 3..9 = even more build messages (not be implemented)."
    echo "    -rom {rom name}"
    echo "       Specifies what ROM to build for. The value given must match the xxx"
    echo "       portion of one of the build_xxx.sh files in the build_scripts directory."
    echo "    -sync {0, no, \"\", 1, yes}"
    echo "       Indicates whether we should do a 'repo sync' of the source before the build."
    echo "    -synccpus ${MIN_CPUS}..?"
    echo "       < 0 = subtract from ${MAX_CPUS} (must end up > 0)"
    echo "         0 = use ${MAX_CPUS} (max on this system)"
    echo "       > 0 = use that value even if greater than ${MAX_CPUS}"
    echo "       Number of CPUs to use when doing a sync"
    echo "    -push {0, no, \"\", 1, yes}"
    echo "       Indicates whether or not to do an 'adb push' of the KANG to the phone."
    echo "    -fpatch {0, no, \"\", 1, yes}"
    echo "       Indicates whether or not to force patching when NOT syncing. Not"
    echo "        recommended unless you did a manual sync and have clean sources."
    echo "    -phone <phone name>"
    echo "       Name of phone to build for, WARNING only tested with 'ace'"
    echo "    -srcdir <path>"
    echo "       Full path to root of where the ROM source is located"
    echo "    -dbox <path>"
    echo "       Full path to a Dropbox directory to copy results to, can be \"\""
    echo "    -make {full, rebuild}"
    echo "       full    = 'make clobber' (or equivalent) followed by a rebuild."
    echo "       rebuild = 'make bacon' (or equivalent for the given ROM)"
    echo "    -run {0, no, \"\", 1, yes}"
    echo "       Determines whether or not we actually do the build or just display"
    echo "       the build information. It's safest to set this to 0 in the .ini and"
    echo "       then override it on the command line after a verifying the info."
    echo ""
    echo "  For more details see the comments in the top of '$0' and build_scripts/init.sh"
    echo ""
  fi
  return 1
fi

if [ "$AB_CLEAN" == "no" ]; then
  #
  # Now read all of patches from the default_patches file. We need to do some
  # verification since someone could have edited this improperly.
  #
  ALL_PATCH_LIST=""
  LINE_NUMBER=0
  DEFAULT_PATCH_FILE=${THE_PATCH_DIR}/default_patches

  if [ -f $DEFAULT_PATCH_FILE ]; then
    while read patch_name  source_type  patch_type  patch_file  patch_dir
    do
      LINE_NUMBER=`expr ${LINE_NUMBER} + 1`

      # Empty lines and lines with a '#' in the first column are ignored
      # Also if the source type does not matche AB_ROM_TYPE we ignore that line
      if [ "$patch_name" != "" ] && [ "${patch_name:0:1}" != "#" ] && [ "$source_type" == "$AB_ROM_TYPE" ]; then
        PATCH_LINE="${patch_name}  ${source_type}  ${patch_type}  ${patch_file}  ${patch_dir}"

        if [ "$patch_type" != "git" ] && [ "$patch_type" != "diff" ]; then
          echo ""
          echo "  ERROR: Invalid patch definition at line ${LINE_NUMBER} of '${DEFAULT_PATCH_FILE}'"
          echo "         Field 3 must be 'git' or 'diff', saw: '${PATCH_LINE}'"
          echo ""
          return 1
        fi

        if [ "$patch_file" == "" ]; then
          echo ""
          echo "  ERROR: Invalid patch definition at line ${LINE_NUMBER} of '${DEFAULT_PATCH_FILE}'"
          echo "         Field 4 is NULL, saw: '${PATCH_LINE}'"
          echo ""
          return 1
        fi

        patch_file=${THE_PATCH_DIR}/$patch_file

        if [ ! -f $patch_file ]; then
          echo ""
          echo "  ERROR: Cannot find patch file specified at line ${LINE_NUMBER} of '${DEFAULT_PATCH_FILE}'"
          echo "         Field 4 is bad, saw: '${PATCH_LINE}'"
          echo ""
          return 1
        fi

        if [ "$patch_dir" == "" ]; then
          echo ""
          echo "  ERROR: Invalid patch directory at line ${LINE_NUMBER} of '${DEFAULT_PATCH_FILE}'"
          echo "         Field 5 is NULL, saw: '${PATCH_LINE}'"
          echo ""
          return 1
        fi

        # PATCH_VAR is the *name* of the variable that we want to test to see if
        # the patch is enabled. For example, if patch_name is TORCH then PATCH_VAR
        # will be AB_PATCH_TORCH. To get the actual value we have to do this
        # ${!PATCH_VAR}
        #
        PATCH_VAR="AB_PATCH_"${patch_name}

        if ([ "$AB_SYNC" == "yes" ] || [ "$FORCE_PATCHING" == "yes" ]) && [ "${!PATCH_VAR}" == "1" ]; then
          patch_dir=${AB_SOURCE_DIR}/$patch_dir

          if [ ! -d $patch_dir ]; then
            echo ""
            echo "  ERROR: Invalid patch directory at line ${LINE_NUMBER} of '${DEFAULT_PATCH_FILE}'"
            echo "         Field 5 is bad, saw: '${PATCH_LINE}'"
            echo ""
            return 1
          fi

          # Save the patch information in a way that is easy to recreate it later.
          ALL_PATCH_LIST=$ALL_PATCH_LIST" ${patch_dir},${patch_file}"
        fi

  #      echo "patch_name  = '$patch_name'"
  #      echo "source_type = '$source_type'"
  #      echo "patch_type  = '$patch_type'"
  #      echo "patch_file  = '$patch_file'"
  #      echo "patch_dir   = '$patch_dir'"
  #      echo "variable    = '${PATCH_VAR}' = ${!PATCH_VAR}"
  #      echo "Patch List  = '${ALL_PATCH_LIST}'"
  #      echo ""
      fi
    done <${DEFAULT_PATCH_FILE}
  fi

fi  # end of test section in which "$CLEAN_ONLY" is 0

ShowMessage ""
ShowMessage "Build information"
ShowMessage "   Build date     = ${UTC_DATE_STRING}"
ShowMessage "   INI file       = ${INI_NAME}"
ShowMessage "   User           = ${USER}"
ShowMessage "   Home dir       = ${HOME}"

if [ "$AB_CLEAN" == "no" ]; then
  ShowMessage "   Phone          = ${AB_PHONE}"
  ShowMessage "   ROM            = ${AB_ROM_TYPE}"
  ShowMessage "   Source dir     = ${AB_SOURCE_DIR}"
  ShowMessage "   Make           = ${AB_MAKE_TYPE}"
  ShowMessage "   Build script   = ${AB_ROM_SCRIPT}"

  if [ "$ALL_PATCH_LIST" != "" ]; then
    ShowMessage ""
    for patch_file in $ALL_PATCH_LIST
    do
      # The items on ALL_PATCH_LIST have the form "patch_dir,patch_file", we
      # only want to show the patch_file part.
      patch_file=${patch_file##*,}
      ShowMessage "   Patch          = ${patch_file}"
    done
  fi

  if [ "$AB_SYNC" == "yes" ]; then
    ShowMessage "   Sync           = yes, using ${NUM_CPUS} CPUs"
  else
    ShowMessage "   Sync           = ${AB_SYNC}"
  fi
  if [ "$AB_SYNC" == "no" ]; then
    if [ "$AB_FORCE_PATCHING" == "yes" ]; then
      ShowMessage "   Force Patching = yes (NOT RECOMMENDED)"
    fi
  fi

  if [ "$AB_DROPBOX_DIR" == "" ]; then
    ShowMessage "   Dropbox dir    = none"
  else
    ShowMessage "   Dropbox dir    = ${AB_DROPBOX_DIR}"
  fi

  ShowMessage "   Push to phone  = ${AB_PUSH_TO_PHONE}"
  ShowMessage "   Official build = ${AB_OFFICIAL}"

  if [ $AB_RUN != "yes" ]; then
    ShowMessage ""
    ShowMessage "(Not building anything because AB_RUN (-run) = 'no')"
  fi

else
  # AB_CLEAN = 'yes'
  ShowMessage "   ROM            = ${AB_ROM_TYPE}"
  ShowMessage "   Source dir     = ${AB_SOURCE_DIR}"
fi
ShowMessage ""

# Return 0 for no error
return 0


