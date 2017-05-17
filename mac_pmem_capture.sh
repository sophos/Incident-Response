#!/bin/sh
#
# Copyright 2017 Sophos Plc
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Mac Live Memory Acquisition:
# This script will capture the live memory from a Mac machine
# Once captured it will gather a small amount of machine information to a text file
# MD5 and SHA1 calculations will also be done on the captured memory once completed

#Variables

scriptname="mac_pmem_capture.sh"
usbdevice="/Volumes/IR_Tools"
macmemimage="$usbdevice/evidence/memory_captures"
osxpmemzip="$usbdevice/tools/osx/osxpmem_2.0.1.zip"
osxpmem="$usbdevice/tools/osx/osxpmem.app"
macname=$(hostname | cut -d "." -f1)
logfile="$usbdevice/logs/$macname-memory-capture.log"
buildinfo="$macmemimage/$macname/osxbuildinfo.txt"

#Functions

osxmem_error ()
{
echo "" | tee -a $logfile
echo "${red}$scriptname: ${1:-"Unknown Error"}" 1>&2
echo "" | tee -a $logfile
echo "Please send $logfile to <emailaddress> for further assistance" | tee -a $logfile
echo "******** $scriptname Finished $(date +%Y%m%d-%H:%M:%S) ********" | tee -a $logfile
echo "$textreset" | tee -a $logfile
exit 1
}

verify_hashes ()
{
echo "Calculating hashes for $macmemimage/$macname/mem-image.aff4:" | tee -a $logfile
echo "Generating MD5..." | tee -a $logfile
cd $macmemimage/$macname
md5 mem-image.aff4 >> mem-image-MD5.log 2>/dev/null &
md5_pid=$!

spin='-\|/'

i=0
while kill -0 $md5_pid 2>/dev/null
do
  i=$(( (i+1) %4 ))
  printf "\r${spin:$i:1}"
  sleep .1
done

echo "" | tee -a $logfile
echo "Generating SHA1..." | tee -a $logfile
openssl sha1 mem-image.aff4 >> mem-image-SHA1.log 2>/dev/null &
sha1_pid=$!

spin='-\|/'

i=0
while kill -0 $sha1_pid 2>/dev/null
do
  i=$(( (i+1) %4 ))
  printf "\r${spin:$i:1}"
  sleep .1
done
}

#START OF SCRIPT

clear

echo "Script started $(date +%Y%m%d-%H:%M:%S)"

echo "" | tee -a $logfile
echo "+-------------------------------------------------------+" | tee -a $logfile
echo "|     Mac Live Memory Acquisition                       |" | tee -a $logfile
echo "+-------------------------------------------------------+" | tee -a $logfile
echo "" | tee -a $logfile

#Check that we are running as root
if [ "$UID" -ne "0" ]; then
   echo "$scriptname must be run as root!" | tee -a $logfile
   echo "Please contact your administrator" | tee -a $logfile
   echo "Script Line: $LINENO: An error has occurred." | tee -a $logfile
   osxmem_error
fi

#Creating machine specific evidence folder
cd $macmemimage
mkdir $macname

if test -d $macmemimage/$macname; then
	echo "$macname folder has been created successfully" | tee -a $logfile
	echo "" | tee -a $logfile
else
	echo "Failed to create $macname folder under $macmemimage" | tee -a $logfile
	exit 1
fi

#Enable ownership of the USB device in order to set correct permissions for pmem kext file
echo "Enabling user/group ownership on $usbdevice:" | tee -a $logfile
sudo diskutil enableOwnership $usbdevice

if [ "$?" == "0" ]; then
    echo "" | tee -a $logfile
else
	echo "" | tee -a $logfile
	echo "Unable to enable ownership on $usbdevice" | tee -a $logfile
	echo "We will be unable to successfully set permissions on the osxpmem.app" | tee -a $logfile
	echo "Aborting script" | tee -a $logfile
	osxmem_error
fi

#Extract the osxpmem app to the usb
echo "Extracting $osxpmemzip:" | tee -a $logfile
cd $usbdevice/tools/osx
unzip $osxpmemzip
echo "" | tee -a $logfile

#Test to ensure that the extraction completed successfully
if test -d $osxpmem; then
	echo "$osxpmem has been extracted successfully" | tee -a $logfile
else
	echo "$osxpmem has failed to extract successfully" | tee -a $logfile
	osxmem_error
fi

#Once osxpmem is extracted successfully set the permissions of the app to root:wheel
echo "" | tee -a $logfile
echo "Setting $osxpmem permissions to root:wheel" | tee -a $logfile
sudo chown -R root:wheel $osxpmem

if [ "$?" == "0" ]; then
    echo "" | tee -a $logfile
else
	echo "" | tee -a $logfile
	echo "Unable to set correct permissions" | tee -a $logfile
	echo "We will be unable to successfully load MacPmem.kext" | tee -a $logfile
	echo "Aborting script" | tee -a $logfile
	osxmem_error
fi

#Check that the command ran successfully and the kext file has the appropriate permissions set
permissions=$(ls -ld $osxpmem/MacPmem.kext | awk '{print $3}')

if [ $permissions == "root" ]; then
	echo "Permissions appear to be applied correctly" | tee -a $logfile
	echo "" | tee -a $logfile
else
	echo "Permissions do not appear to have been applied correctly to $osxpmem" | tee -a $logfile
	echo "" | tee -a $logfile
	osxmem_error
fi

#Start the kext
echo "Loading MacPmem.kext" | tee -a $logfile
sudo kextload $osxpmem/MacPmem.kext

if [ "$?" == "0" ]; then
    echo "" | tee -a $logfile
else
	echo "" | tee -a $logfile
	echo "Failed to load MacPmem.kext" | tee -a $logfile
	echo "Aborting script" | tee -a $logfile
	osxmem_error
fi

#Start capturing the memory from the machine
echo "Starting memory capture:" | tee -a $logfile
cd $osxpmem
sudo ./osxpmem -o "${macmemimage}/${macname}/mem-image.aff4"
echo "" | tee -a $logfile

#Unload the kext
echo "Unloading the MacPmem.kext" | tee -a $logfile
sudo kextunload $osxpmem/MacPmem.kext

if [ "$?" == "0" ]; then
    echo "" | tee -a $logfile
else
	echo "Failed to unload MacPmem.kext" | tee -a $logfile
	echo ""
fi

#Check if the file is in the correct location
if test -f $macmemimage/$macname/mem-image.aff4; then
	echo "Memory file is present under $macmemimage/$macname" | tee -a $logfile
	echo "" | tee -a $logfile
	verify_hashes
else
	echo "Memory image file doesnt appear to be under $macmemimage/$macname" | tee -a $logfile
	echo "Please verify MD5 and SHA1 hashes manually" | tee -a $logfile
	echo "" | tee -a $logfile
fi

#Gather Mac build information
echo "" | tee -a $logfile
echo "Gathering basic Mac information" | tee -a $logfile
sw_vers >> $buildinfo

#Gather Mac architecture and append to the osx build information
echo "Architecture: $(uname -a | cut -d/ -f2)" >> $buildinfo
echo "" | tee -a $logfile

echo "Script complete" | tee -a $logfile

exit 0