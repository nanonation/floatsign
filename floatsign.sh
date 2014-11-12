# !/bin/bash

# Copyright (c) 2011 Float Mobile Learning
# http://www.floatlearning.com/
# Extension Copyright (c) 2013 Weptun Gmbh
# http://www.weptun.de
#
# Extended by Ronan O Ciosoig January 2012
#
# Extended by Patrick Blitz, April 2013
#
# Extended by John Turnipseed and Matthew Nespor, November 2014
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# Please let us know about any improvements you make to this script!
# ./floatsign source "iPhone Distribution: Name" -p "path/to/profile" [-d "display name"]  [-e entitlements] [-k keychain] -b "BundleIdentifier" outputIpa
#
#
# Modifed 26th January 2012
#
# new features January 2012:
# 1. change the app display name
#
# new features April 2013
# 1. specify the target bundleId on the command line
# 2. correctly handles entitlements for keychain-enabled resigning
#
# new features November 2014
# 1. now re-signs embedded iOS frameworks, if present, prior to re-signing the application itself
# 2. extracts the team-identifier from provisioning profile and uses it to update previous entitlements
# 3. fixed bug in packaging if -e flag is used
# 4. renamed 'temp' directory and made it a variable so it can be easily modified
# 5. various code formatting and logging adjustments
# 


function checkStatus {

if [ $? -ne 0 ];
then
	echo "Had an Error, aborting!"
	exit 1
fi
}

if [ $# -lt 3 ]; then
	echo "usage: $0 source identity -p provisioning [-e entitlements] [-d displayName] -b bundleId outputIpa" >&2
	echo "       -p and -b are optional, but their use is heavly recommended" >&2
	exit 1
fi

ORIGINAL_FILE="$1"
CERTIFICATE="$2"
NEW_PROVISION=
ENTITLEMENTS=
BUNDLE_IDENTIFIER=""
DISPLAY_NAME=""
PROVISIONING_PROFILE_PREFIX=""
TEAM_IDENTIFIER=""
KEYCHAIN=""
TEMP_DIR="_floatsignTemp"

# options start index
OPTIND=3
while getopts p:d:e:k:b: opt; do
	case $opt in
		p)
			NEW_PROVISION="$OPTARG"
			echo "Specified provisioning profile: $NEW_PROVISION" >&2
			;;
		d)
			DISPLAY_NAME="$OPTARG"
			echo "Specified display name: $DISPLAY_NAME" >&2
			;;
		e)
			ENTITLEMENTS="$OPTARG"
			echo "Specified signing entitlements: $ENTITLEMENTS" >&2
			;;
		b)
			BUNDLE_IDENTIFIER="$OPTARG"
			echo "Specified bundle identifier: $BUNDLE_IDENTIFIER " >&2
			;;
		k)
			KEYCHAIN="$OPTARG"
			echo "Specified Keychain to use: $KEYCHAIN " >&2
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			exit 1
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			exit 1
			;;
	esac
done

shift $((OPTIND-1))

NEW_FILE="$1"

# Check for and remove the temporary directory if it already exists
if [ -d "$TEMP_DIR" ]; 
then
	echo "Removing previous temporary directory: '$TEMP_DIR'" >&2
	rm -Rf "$TEMP_DIR"
fi

# Check if the supplied file is an ipa or an app file
if [ "${ORIGINAL_FILE#*.}" = "ipa" ]
then
	# Unzip the old ipa quietly
	unzip -q "$ORIGINAL_FILE" -d $TEMP_DIR
	checkStatus
elif [ "${ORIGINAL_FILE#*.}" = "app" ]
then
	# Copy the app file into an ipa-like structure
	mkdir -p "$TEMP_DIR/Payload"
	cp -Rf "${ORIGINAL_FILE}" "$TEMP_DIR/Payload/${ORIGINAL_FILE}"
	checkStatus
else
	echo "Error: Only can resign .app files and .ipa files." >&2
	exit
fi

# check the keychain
if [ "${KEYCHAIN}" != "" ];
then
	security list-keychains -s $KEYCHAIN
	security unlock $KEYCHAIN
	security default-keychain -s $KEYCHAIN
fi

# Set the app name
# The app name is the only file within the Payload directory
APP_NAME=$(ls "$TEMP_DIR/Payload/")
echo "APP_NAME=$APP_NAME" >&2

# Make sure that PATH includes the location of the PlistBuddy helper tool as its location is not standard
export PATH=$PATH:/usr/libexec


# Read in current values from the app
CURRENT_NAME=`PlistBuddy -c "Print :CFBundleDisplayName" "$TEMP_DIR/Payload/$APP_NAME/Info.plist"`
CURRENT_BUNDLE_IDENTIFIER=`PlistBuddy -c "Print :CFBundleIdentifier" "$TEMP_DIR/Payload/$APP_NAME/Info.plist"`
if [ "${BUNDLE_IDENTIFIER}" == "" ];
then
	BUNDLE_IDENTIFIER=`egrep -a -A 2 application-identifier "${NEW_PROVISION}" | grep string | sed -e 's/<string>//' -e 's/<\/string>//' -e 's/ //' | awk '{split($0,a,"."); i = length(a); for(ix=2; ix <= i;ix++){ s=s a[ix]; if(i!=ix){s=s "."};} print s;}'`
	if [[ "${BUNDLE_IDENTIFIER}" == *\** ]]; then
		echo "Bundle Identifier contains a *, using the current bundle identifier" >&2
		BUNDLE_IDENTIFIER=$CURRENT_BUNDLE_IDENTIFIER;
	fi
	checkStatus
fi

echo "Bundle Identifier is ${BUNDLE_IDENTIFIER}" >&2


# Update the CFBundleDisplayName property in the Info.plist if a new name has been provided
if [ "${DISPLAY_NAME}" != "" ];
then
	#echo "read Info.plist file" "$TEMP_DIR/Payload/$ORIGINAL_FILE/Info.plist" >&2
	#    CURRENT_NAME=/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "$TEMP_DIR/Payload/$ORIGINAL_FILE/Info.plist"
	echo "Changing display name from $CURRENT_NAME to $DISPLAY_NAME" >&2

	`PlistBuddy -c "Set :CFBundleDisplayName $DISPLAY_NAME" "$TEMP_DIR/Payload/$APP_NAME/Info.plist"`
	#    PlistBuddy -c "Set :CFBundleDisplayName $DISPLAY_NAME" $TEMP_DIR/Payload/$ORIGINAL_FILE/Info.plist
fi


# Replace the embedded mobile provisioning profile
if [ "$NEW_PROVISION" != "" ];
then
	echo "Adding the new provision: $NEW_PROVISION" >&2
	ENTITLEMENTS_TEMP=`/usr/bin/codesign -d --entitlements - "$TEMP_DIR/Payload/$APP_NAME" |  sed -E -e '1d'`
	if [ -n "$ENTITLEMENTS_TEMP" ]; then
		echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>$ENTITLEMENTS_TEMP" > "$TEMP_DIR/newEntitlements"
	fi
	#	echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>`/usr/bin/codesign -d --entitlements - "$TEMP_DIR/Payload/$APP_NAME" |  sed -E -e '1d'`" > "$TEMP_DIR/newEntitlements"
	cp "$NEW_PROVISION" "$TEMP_DIR/Payload/$APP_NAME/embedded.mobileprovision"
	PROVISIONING_PROFILE_PREFIX=`grep '<key>application-identifier</key>' "$TEMP_DIR/Payload/$APP_NAME/embedded.mobileprovision" -A 1 --binary-files=text | sed -E -e '/<key>/ d' -e 's/(^.*<string>)//' -e 's/([A-Z0-9]*)(.*)/\1/'`
	checkStatus
	TEAM_IDENTIFIER=`grep '<key>com.apple.developer.team-identifier</key>' "$TEMP_DIR/Payload/$APP_NAME/embedded.mobileprovision" -A 1 --binary-files=text | sed -E -e '/<key>/ d' -e 's/(^.*<string>)//' -e 's/([A-Z0-9]*)(.*)/\1/'`
	checkStatus
fi


#if the current bundle identifier is different from the new one in the provisioning profile, then change it.
if [ "$CURRENT_BUNDLE_IDENTIFIER" != "$BUNDLE_IDENTIFIER" ];
then
	echo "Updating the bundle identifier from '$CURRENT_BUNDLE_IDENTIFIER'  to '$BUNDLE_IDENTIFIER'" >&2
	`PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_IDENTIFIER" "$TEMP_DIR/Payload/$APP_NAME/Info.plist"`
	checkStatus
fi


# Check for and resign any embedded frameworks (new feature for iOS 8 and above apps)
FRAMEWORKS_DIR="$TEMP_DIR/Payload/$APP_NAME/Frameworks"
if [ -d "$FRAMEWORKS_DIR" ];
then
	echo "Resigning embedded frameworks using certificate: $CERTIFICATE" >&2
	for framework in "$FRAMEWORKS_DIR"/*
	do
		if [[ "$framework" == *.framework ]]
		then
			/usr/bin/codesign -f -s "$CERTIFICATE" "$framework"
			checkStatus
		else
			echo "Ignoring non-framework: $framework" >&2
		fi
	done
fi


# Resign the application
echo "Resigning application using certificate: $CERTIFICATE" >&2
if [ "$ENTITLEMENTS" != "" ];
then
	echo "Using Entitlements: $ENTITLEMENTS" >&2
	/usr/bin/codesign -f -s "$CERTIFICATE" --entitlements="$ENTITLEMENTS" "$TEMP_DIR/Payload/$APP_NAME"
	checkStatus
else
	if [ "$PROVISIONING_PROFILE_PREFIX" != "" ] && [ -s "$TEMP_DIR/newEntitlements" ];
	#if [ -s "$TEMP_DIR/newEntitlements" ];
	then
		echo "Using existing entitlements updated with bundle identifier: $PROVISIONING_PROFILE_PREFIX.$BUNDLE_IDENTIFIER" >&2
		if [ "$TEAM_IDENTIFIER" != "" ];
		then
			echo "and team identifier: $TEAM_IDENTIFIER" >&2
			PlistBuddy -c "Set :com.apple.developer.team-identifier ${TEAM_IDENTIFIER}" "$TEMP_DIR/newEntitlements"
			checkStatus
		fi
		PlistBuddy -c "Set :application-identifier ${PROVISIONING_PROFILE_PREFIX}.${BUNDLE_IDENTIFIER}" "$TEMP_DIR/newEntitlements"
		checkStatus
		PlistBuddy -c "Set :keychain-access-groups:0 ${PROVISIONING_PROFILE_PREFIX}.${BUNDLE_IDENTIFIER}" "$TEMP_DIR/newEntitlements"
		checkStatus
		plutil -lint "$TEMP_DIR/newEntitlements" > /dev/null
		checkStatus
		/usr/bin/codesign -f -s "$CERTIFICATE" --entitlements="$TEMP_DIR/newEntitlements" "$TEMP_DIR/Payload/$APP_NAME"
		checkStatus
	else
		echo "Without entitlements" >&2
		/usr/bin/codesign -f -s "$CERTIFICATE" "$TEMP_DIR/Payload/$APP_NAME"
		checkStatus
	fi
fi

# Remove the temporary entitlements file if one was created
rm -f "$TEMP_DIR/newEntitlements"

# Repackage quietly
echo "Repackaging as $NEW_FILE" >&2

# Zip up the contents of the "$TEMP_DIR" folder
# Navigate to the temporary directory (sending the output to null)
# Zip all the contents, saving the zip file in the above directory
# Navigate back to the orignating directory (sending the output to null)
pushd "$TEMP_DIR" > /dev/null
zip -qr "../$TEMP_DIR.ipa" *
popd > /dev/null

# Move the resulting ipa to the target destination
mv "$TEMP_DIR.ipa" "$NEW_FILE"

# Remove the temp directory
rm -rf "$TEMP_DIR"
