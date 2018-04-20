#!/bin/bash
echo "[*] Compiling DuMaMay.."
$(which xcodebuild) clean build CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" -sdk `xcrun --sdk iphoneos --show-sdk-path` -arch arm64
mv Downloads/DuMaMay/dumamay/Z_I_Payload/DuMaMay.app DuMaMay.app 
mkdir Payload
mv duMaMay.app Payload/DuMaMay.app
cp DuMaMay.app
PASTE Downloads/DuMaMay/dumamay/Z_I_Payload/DuMaMay.app
echo "[*] Zipping into .ipa"
zip -r9 DuMaMay.ipa Payload/DuMaMay.app
rm -rf build Payload
mv DuMaMay.ipa Desktop/DuMaMay.ipa
echo "[*] Done! Install .ipa with Impactor"