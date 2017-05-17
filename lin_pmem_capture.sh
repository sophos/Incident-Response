#!/bin/bash
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
# Linux Live Memory Acquisition:
# This script will capture the memory from a Linux machine
# Once captured it will gather a small amount of machine information to a text file
# MD5 and SHA1 calculations will also be done on the captured memory once completed

#Variables

scriptname="lin_pmem_capture.sh"
loggedinusr=$(who am i | awk '{print $1}')
usbdevice="/media/$loggedinusr/IR_Tools"
linmemimage="$usbdevice/evidence/memory_captures"
linpmemgz="$usbdevice/tools/linux/linpmem_2.0.1.gz"
linpmem="$usbdevice/tools/linux/linpmem_2.0.1"
linname=$(uname -n)
logfile="$usbdevice/logs/$linname-memory-capture.log"
buildinfo="$linmemimage/$linname/linbuildinfo.txt"

#Functions

linmem_error ()
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
echo "Calculating hashes for $linmemimage/$linname/mem-image.aff4:" | tee -a $logfile
echo "Generating MD5..." | tee -a $logfile
cd $linmemimage/$linname
md5sum mem-image.aff4 >> mem-image-MD5.log 2>/dev/null &
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
sha1sum mem-image.aff4 >> mem-image-SHA1.log 2>/dev/null &
sha1_pid=$!

spin='-\|/'

i=0
while kill -0 $sha1_pid 2>/dev/null
do
  i=$(( (i+1) %4 ))
  printf "\r${spin:$i:1}"
  sleep .1
done

echo "" | tee -a $logfile
}

#START OF SCRIPT

clear

echo "Script started $(date +%Y%m%d-%H:%M:%S)"

echo "" | tee -a $logfile
echo "+-------------------------------------------------------+" | tee -a $logfile
echo "|     Linux Live Memory Acquisition                     |" | tee -a $logfile
echo "+-------------------------------------------------------+" | tee -a $logfile
echo "" | tee -a $logfile

#Check that we are running as root
if [ "$UID" -ne "0" ]; then
   echo "$scriptname must be run as root!" | tee -a $logfile
   echo "Please contact your administrator" | tee -a $logfile
   echo "Script Line: $LINENO: An error has occurred." | tee -a $logfile
   linmem_error
fi

#Creating machine specific evidence folder
cd $linmemimage
mkdir $linname

if test -d $linmemimage/$linname; then
	echo "$linname folder has been created successfully" | tee -a $logfile
	echo "" | tee -a $logfile
else
	echo "Failed to create $linname folder under $linmemimage" | tee -a $logfile
	exit 1
fi

#Extract the osxpmem app to the usb
echo "Extracting $linpmemgz:" | tee -a $logfile
gunzip $linpmemgz 2>/dev/null

#Test to ensure that the extraction completed successfully
if test -f $linpmem; then
	echo "$linpmem has been extracted successfully" | tee -a $logfile
else
	echo "$linpmem has failed to extract successfully" | tee -a $logfile
	linmem_error
fi

#Start capturing the memory from the machine
echo "" | tee -a $logfile
echo "Starting memory capture:" | tee -a $logfile
cd $usbdevice/tools/linux/
sudo $linpmem -m -v -o "${linmemimage}/${linname}/mem-image.aff4"
echo "" | tee -a $logfile

#Check if the file is in the correct location
if test -f $linmemimage/$linname/mem-image.aff4; then
	echo "Memory file is present under $linmemimage/$linname" | tee -a $logfile
	echo "" | tee -a $logfile
	verify_hashes
else
	echo "Memory image file doesnt appear to be under $linmemimage/$linname" | tee -a $logfile
	echo "Please verify MD5 and SHA1 hashes manually" | tee -a $logfile
	echo "" | tee -a $logfile
fi

#Gather Linux build information
echo "" | tee -a $logfile
echo "Gathering basic Linux information" | tee -a $logfile
echo "Machine Name: $(uname -n)" >> $buildinfo
echo "Opertating System: $(uname -o)" >> $buildinfo
echo "Kernel Version: $(uname -v | awk '{print $1}')" >> $buildinfo
echo "Architecture: $(uname -p)" >> $buildinfo
echo "" | tee -a $logfile

echo "Script complete" | tee -a $logfile

exit 0