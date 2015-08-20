#!/bin/sh

#
# Assumes the following is installed:
#
#  svn
#  brew
#  python via brew
#  virtualenv via pip in brew
#
# We can probably check all that for the sake of running this hands-free
# in an automated manner.
#

set -x

REVISION=4733651b7fe2133ce3edfc6329253df696b59408
BUILDID=32

DATESTAMP=`date '+%Y%m%d-%H%M'`
BUILDNAME="FennecAurora-L10N-$BUILDID-$DATESTAMP"
ASSETS="$BUILDNAME-Assets"


# We put all results in $BUILDNAME-Assets

mkdir $ASSETS

cp FennecAurora-L10N.plist.tmpl $ASSETS/FennecAurora-L10N.plist
perl -pi -e "s/BUILDID/$BUILDID/g;" $ASSETS/FennecAurora-L10N.plist
perl -pi -e "s/DATESTAMP/$DATESTAMP/g;" $ASSETS/FennecAurora-L10N.plist

cp l10n.html.tmpl $ASSETS/l10n.html
perl -pi -e "s/BUILDID/$BUILDID/g;" $ASSETS/l10n.html
perl -pi -e "s/DATESTAMP/$DATESTAMP/g;" $ASSETS/l10n.html


# Clone the project into $BUILDNAME

if [ -d $BUILDNAME ]; then
  echo "There already is a $BUILDDIR checkout. Aborting to let you decide what to do."
  exit 1
fi

git clone https://github.com/mozilla/firefox-ios.git $BUILDNAME || exit 1
cd $BUILDNAME || exit 1

git checkout $REVISION || exit 1

# Our special app delegate

cp AuroraAppDelegate.swift $BUILDNAME/Client/Application/

# Create a virtualenv with the python modules that we need

rm -rf python-env || exit 1
virtualenv python-env || exit 1
source python-env/bin/activate || exit 1
brew install libxml2 || exit 1
STATIC_DEPS=true pip install lxml || exit 1

# Import locales

scripts/import-locales.sh || exit 1


# BUILDING WORKS, SIGNING FAILS. SAD.

#echo "Now open Xcode to make a build :-( Save it as Fennec-Aurora-L10N-$BUILDID.ipa and scp it:"
#echo
#echo "    scp ~/Desktop/FennecAurora-L10N-31.ipa people.mozilla.org:/home/iosbuilds/builds/l10n/"
#echo "Do not forget to update the date in l10n.html"

# Make a build and export it

xcodebuild clean archive -archivePath ./$BUILDNAME.xcarchive -project Client.xcodeproj -scheme FennecAurora -sdk iphoneos || exit 1
xcodebuild -exportArchive -archivePath ./$BUILDNAME.xcarchive -exportFormat 'ipa' -exportPath ./$BUILDNAME.ipa -exportProvisioningProfile 'Fennec Aurora' || exit 1

cp $BUILDNAME.ipa ../$ASSETS/ || exit 1

# Upload files

scp ../$ASSETS/l10n.html people.mozilla.org:/home/iosbuilds/l10n.html || exit 1
scp ../$ASSETS/FennecAurora-L10N.plist people.mozilla.org:/home/iosbuilds/FennecAurora-L10N.plist || exit 1
scp ../$ASSETS/$BUILDNAME.ipa people.mozilla.org:/home/iosbuilds/builds/l10n/$BUILDNAME.ipa || exit 1
