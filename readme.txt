This set of scripts and .ini files are for building various Android KANGs,
although they have only been tested for Desire HD (ace) builds.

These build scripts and supporting files can reside anywhere, but the directory
structure must be maintained otherwise build.sh and possibly init.sh will require
changes. The directory containing build.sh must also contain 2 subdirectories
 - build_scripts: *.sh and *.ini files
 - patche: files for source patching, currently there are only CM7 patches

In order to use these scripts you must have the desired Android source code
checked out. For example, if you are building CM7 for Desire HD you should
have followed all these instructions
  http://wiki.cyanogenmod.com/index.php?title=Compile_CyanogenMod_for_Ace

For LorD ClockaN's IceColdSandwich you need to already have done
 repo init -u git://github.com/IceColdSandwich/android.git -b ics
 repo sync

By default the .ini files are setup to display some information about the build
without actually building anything. For example,
  build.sh -ini build_cm7.ini

If the build info (from the above command) looks ok and you want to actually do
the build then add '-run yes' to the command line like this
  build.sh -ini build_cm7.ini -run yes

build_ics.ini is for building an ICS KANG although it's almost identical to cm7

build_lord.ini is for build LorD ClockaN's version of ICS
  build.sh -ini build_lord.ini

All items in the .ini files can be overriden on the command line, see init.ini
for more details. If you find that you always override some items then you should
make your own copy of the .ini file and edit it to make your life easier.

One item that you will most likely need to change in the .ini file is AB_SOURCE_DIR.
This needs to point to the top level directory containing the source that you built.
For example, build_lord.ini assumes the source code is in ${HOME}/android/ics, but
if your system has it in ~/IceColdSandwich then you can do this on the command line
  build.sh -ini build_lord.ini -srcdir ~/IceColdSandwich
or in the .ini file you can do this
  AB_SOURCE_DIR=${HOME}/IceColdSandwich

