#!/bin/bash
echo "[*] Compiling DuMaMay.."
$(which xcodebuild) clean build CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" -sdk `xcrun --sdk iphoneos --show-sdk-path` -arch arm64
mv build/Release-iphoneos/DuMaMay.app dumamay.app
mkdir Payload
mv dumamay.app Payload/dumamay.app
echo "[*] Zipping into .ipa"
zip -r9 DuMaMay.ipa Payload/dumamay.app
rm -rf build Payload
echo "[*] Done! Install .ipa with Impactor"
