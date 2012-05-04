These scripts are for building Android KANGs, such as LorD ClockaN's
IceColdSandwhich, general ICS and CM7.

They have only been tested for Desire HD (ace) builds.

You can put these files anywhere, but you must keep the same directory structure.
  [top] (build.sh is here)
    |
    +--- build_scripts (contains .sh and .ini files)
    +--- patches (files for patching source code, currently only useful for CM7)

These scripts only help you to build source code that you have already checked
out. If you need help doing that here is a good link for CM7 Ace
  http://wiki.cyanogenmod.com/index.php?title=Compile_CyanogenMod_for_Ace

For LorD ClockaN's IceColdSandwich you should have done this to get the source
 repo init -u git://github.com/IceColdSandwich/android.git -b ics
 repo sync

The command syntax for building something is
  build.sh [-ini <ini file>] [options] [log options]

  1) Normally '-ini <ini file>' is always used. It can be omitted, but then you
     must provide many other command line options. The purpose of using the .ini
     file is so you do not have to specify a lot of options.

  2) For the list of options you can either look at init.sh or you can type
       build.sh -help

  3) Normally all the output from a build goes to the screen. You can use various
     Linux redirect commands to control the output. For example this will send all
     the output to both the screen and a logfile named theLog.log
       build.sh [-ini <ini file>] [options] | 2>&1 tee theLog.log

  4) By default the .ini files set AB_RUN=0 (same as '-run 0' on the command line).
     This causes the scripts to display the build information without actually
     doing the build. This allows you to check that everything is OK before
     building. If you really want to build run the same command again, but add
     '-run 1' this time. Of course you can change the .ini file, but I prefer to
     do a double check before actually starting the build.

The .ini files specify many build settings. Most of the defaults should be usable,
but you can always change them to your liking. One option you probably will need
to change is AB_SOURCE_DIR. This must specify the top level directory on *your*
system where you checked out the source code. For example, if you want to build
LorD ClockaN's ICS and you checked out that source code to ~/work/lc-ics then you
need to do one of the following in order to build:
  1) Edit build_scripts/build_lord.ini and change AB_SOURCE_DIR to
       AB_SOURCE_DIR=~/work/lc-ics
     (or AB_SOURCE_DIR=${HOME}/work/lc-ics)
  2) On the command line you can override the value of AB_SOURCE_DIR on the
     build.sh command line using
       -srcdir ~/work/lc-ics

By default the .ini files are setup to display some information about the build
without actually building anything. For example if you do this
  build.sh -ini build_lord.ini

You will see information like this
Build information
   Build date     = Tue May  1 17:06:53 UTC 2012
   INI file       = /home/chezbel/android/ics/vendor/icecold/build_scripts/build_lord.ini
   User           = chezbel
   Home dir       = /home/chezbel
   Phone          = ace
   ROM            = lord
   Source dir     = /home/chezbel/android/ics
   Make           = rebuild
   Build script   = /home/chezbel/android/ics/vendor/icecold/build_scripts/build_lord.sh
   Sync           = yes, using 5 CPUs
   Dropbox dir    = none
   Push to phone  = yes
   Official build = no

  (Not building anything because AB_RUN (-run) = 'no')

If this information is ok and you want to actually do the build then add '-run yes'
or '-run -1' to the command line like this
  build.sh -ini build_lord.ini -run 1

So far we have tried to match the names of .ini and .sh files. For example when
you use build_lord.ini it specifies 'ROM=lord' and this will cause build.sh to
call build_scripts/build_lord.sh to finish the build.
