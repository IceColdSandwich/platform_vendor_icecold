This set of scripts and .ini files are for building various Android KANGs
although they have only been tested for Desire HD (ace) builds.

The files can reside anywhere, but the directory structure of the .zip file must
be maintained otherwise build.sh and possibly init.sh will require changes.

build.sh is expected to be in the top level directory of all these files. Below
this there should be the following 2 directories
  build_scripts - *.sh and *.ini files
  patches - files for various source patching, currently there are only CM7 patches

Of course in order to use these scripts you must have the desired Android source
code checked out. For example, if you are building CM7 for Desire HD you should
have followed all these instructions
  http://wiki.cyanogenmod.com/index.php?title=Compile_CyanogenMod_for_Ace

Once the files are extracted you can do a build. For example, assuming the
build_cm7.ini file has not been modified then the following will show the build
information, but will not actually build anything
  build.sh -ini build_cm7.ini

If the build info looks ok and want to actually do the build then do this
  build.sh -ini build_cm7.ini -run yes

build_ics.ini is for building an ICS KANG although it's almost identical to cm7

build_lord.ini is for build a LorDClockaN version of ICS. There are a few differences
from a normal ICS build.

All items in the .ini files can be overriden on the command line. See init.ini
for more details.

FYI, in the .ini files the AB_SOURCE_DIR probably needs to be updated since you
probably installed into a different path than me.

Brian
