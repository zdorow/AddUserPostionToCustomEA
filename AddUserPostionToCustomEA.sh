#!/bin/sh
####################################################################################################
#   
#   Description: This script uses hard coded values to populate a custom EA with a users position
#   Author: Zach Dorow
#   Last Edited: Sept 21, 2018
#   
#   NOTE: If it seems to be successful and is not populating double check the EA ID.
#
#   THIS SCRIPT IS NOT AN OFFICIAL PRODUCT OF JAMF AS SUCH IT IS PROVIDED WITHOUT WARRANTY OR SUPPORT.
#
#   BY USING THIS SCRIPT, YOU AGREE THAT JAMF IS UNDER NO OBLIGATION TO SUPPORT, DEBUG, OR OTHERWISE 
#   MAINTAIN THIS SCRIPT AND IS NOT LIABLE FOR ANYTHING IT DOES. WE ARE PROVIDING A CUSTOM SERIVCE 
#   AT NO COST TO YOU. PLEASE BE NICE! THANKS FOR UNDERSTANDING! TAKE DATABASE BACKUPS!
#
####################################################################################################
#

# FILL IN THIS!!
# Jamf Pro FQDN jss.company.com:8443 or company.jamfcloud.com
jssURL=""
[ -z "$jssURL" ] && echo "Please enter the FQDN for your Jamf PRO server into the script" && exit 99

# FILL IN THIS!!
# Put in the API username in passwork example: apiUserAndPass="admin:jamf1234"
apiUserAndPass=""
[ -z "$apiUserAndPass" ] && echo "Please enter the API username and password for your Jamf PRO server into the script" && exit 99

# FILL IN THIS!!
# Defining the custom EA field we want to populate
# Example ea=4
ea=
[ -z "$ea" ] && echo "Please enter the id of the EA for your Jamf PRO server into the script" && exit 99

# End of user supplied hard coded fields

#Testing supplied url and credentials separate error messages for both
echo "Trying a test call to the Jamf Pro API"

test=$(curl --fail -ksu "$apiUserAndPass" "https://"$jssURL"/JSSResource/users" -X GET)
status=$?

if [ $status -eq 6 ]; then
	echo ""
	echo "The Jamf Pro URL is incorrect. Please edit the URL and try again." 
	echo "If the error persists please check permissions and internet connection" 
	echo ""
	exit 99
elif [ $status -eq 22 ]; then
	echo ""
	echo "Username and/or password is incorrect. Please edit and try again."
	echo "If the error persists please check permissions and internet connection" 
	echo ""
	exit 99
elif [ $status -eq 0 ]; then
    echo ""
    echo "Connection test successful! Starting API calls...."
    echo ""
else
    echo ""
    echo "Something really went wrong,"
    echo "Lets try this again."
    exit 99
fi

# Temp Files file paths - Please do not modify.
xml=`mktemp /tmp/addInfoXML.XXXXXXXXX`
file1=`mktemp /tmp/addInfoFile.XXXXXXXXX` # File used to get user ids
csvFile=`mktemp /tmp/addInfoCSV.XXXXXXXXX` # CSV file used as our counter and user id variable for our cURL loop

# Collection of user ids
/usr/bin/curl -sk -u $apiUserAndPass -H "Accept: application/xml" https://"$jssURL"/JSSResource/users | xmllint --format - --xpath /users/user/id > $file1

# Building of user id list
/bin/cat $file1 | grep '<id>' | cut -f2 -d">" | cut -f1 -d"<" >> $csvFile

# Getting array of ids for loop
count=`cat $csvFile | awk -F, '{print $1}'`

# Setting delimiter
IFS=$'\n'

# Start of loop going through ids
for i in ${count}
do

# Collection of the position field 
position=`/usr/bin/curl -sk -u $apiUserAndPass -H "Accept: application/xml" https://"$jssURL"/JSSResource/users/id/$i | xmllint  --xpath '/user/position/text()' -`

# Ensuring the postion fiels is not blank for the cURL
if [[ "$position" = "" ]]; then
    echo ""
    echo "*******************************************************"
    echo "User id: $i does not have the position field filled in."
    echo "*******************************************************"
    echo ""
    
# If not blank then copy postion to custom EA    
else
echo "Adding $position to user record"
curl -sku "$apiUserAndPass" https://"$jssURL"/JSSResource/users/id/$i -H "content-type: application/xml" -d "<?xml version=\"1.0\" encoding=\"UTF-8\"?><user>\t<extension_attributes>\t<extension_attribute>\t<id>$ea</id>\t<name>TEST_EA</name>\t<type>String</type>\t<value>$position</value>\t</extension_attribute>\t</extension_attributes>\t</user>" -X PUT 
echo ""
fi

# This can be used to mass populate the postion field if uncommented and the postion field edited. 
# To use this comment out line if [[ $position = "" ]]; then to the fi Line 89 to 101
# curl -sku "$apiUserAndPass" https://"$jssURL"/JSSResource/users/id/$i -H "content-type: application/xml" -d "<user><position>TallTaleTeller</position></user>" -X PUT 

done

# Removal of temp files
rm -rf $xml
rm -rf $file1
rm -rf $csvFile

exit 0


