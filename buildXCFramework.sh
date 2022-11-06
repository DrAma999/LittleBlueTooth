#!/bin/bash


makeXCFramework() {
  FRAMEWORK_NAME=$1
  BUILD_CONFIGURATION=$2
  SCHEME_NAME=$1

  echo "NAME: ${FRAMEWORK_NAME}"
  echo "CONFIGURATION: ${BUILD_CONFIGURATION}"
  echo "SCHEME: ${SCHEME_NAME}"


  ARCHIVE_PATH="$(pwd)/xcarchives"
  IOS_SIMULATOR_ARCHIVE_PATH="${ARCHIVE_PATH}/${SCHEME_NAME}-iphonesimulator.xcarchive"
  IOS_DEVICE_ARCHIVE_PATH="${ARCHIVE_PATH}/${SCHEME_NAME}-iphoneos.xcarchive"
  TV_SIMULATOR_ARCHIVE_PATH="${ARCHIVE_PATH}/${SCHEME_NAME}-appletvsimulator.xcarchive"
  TV_DEVICE_ARCHIVE_PATH="${ARCHIVE_PATH}/${SCHEME_NAME}-appletvos.xcarchive"
  WATCH_SIMULATOR_ARCHIVE_PATH="${ARCHIVE_PATH}/${SCHEME_NAME}-watchsimulator.xcarchive"
  WATCH_DEVICE_ARCHIVE_PATH="${ARCHIVE_PATH}/${SCHEME_NAME}-watchos.xcarchive"
  MACOS_ARCHIVE_PATH="${ARCHIVE_PATH}/${SCHEME_NAME}-macosx.xcarchive"
  CATALYST_ARCHIVE_PATH="${ARCHIVE_PATH}/${SCHEME_NAME}-catalyst.xcarchive"
  OUTPUT_FRAMEWORK_PATH="$(pwd)/xcframeworks"

  printf "\n"
  printf "\n"
  echo "${FRAMEWORK_NAME}"
  echo "Cleaning up old archives"
  rm -rf "${ARCHIVE_PATH}"

  printf "\n"
  printf "\n"
  echo "Creating xcarchives ${FRAMEWORK_NAME} using ${BUILD_CONFIGURATION} configuration"

  printf "\n"
  printf "\n"
  echo "iOS Simulator xcarchive"
  xcodebuild archive \
  -project LittleBlueTooth.xcodeproj \
  -scheme LittleBlueTooth \
  -configuration ${BUILD_CONFIGURATION} \
  -archivePath ${IOS_SIMULATOR_ARCHIVE_PATH} \
  -sdk iphonesimulator \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

  printf "\n"
  printf "\n"
  echo "iOS Device xcarchive"
  xcodebuild archive \
  -project LittleBlueTooth.xcodeproj \
  -scheme LittleBlueTooth \
  -configuration ${BUILD_CONFIGURATION} \
  -archivePath ${IOS_DEVICE_ARCHIVE_PATH} \
  -sdk iphoneos \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

  printf "\n"
  printf "\n"
  echo "tvOS Simulator xcarchive"
  xcodebuild archive \
  -project LittleBlueTooth.xcodeproj \
  -scheme LittleBlueTooth \
  -configuration ${BUILD_CONFIGURATION} \
  -archivePath ${TV_SIMULATOR_ARCHIVE_PATH} \
  -sdk appletvsimulator \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

  printf "\n"
  printf "\n"
  echo "tvOS Device xcarchive"
  xcodebuild archive \
  -project LittleBlueTooth.xcodeproj \
  -scheme LittleBlueTooth \
  -configuration ${BUILD_CONFIGURATION} \
  -archivePath ${TV_DEVICE_ARCHIVE_PATH} \
  -sdk appletvos \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

  printf "\n"
  printf "\n"
  echo "watchOS Device xcarchive"
  xcodebuild archive \
  -project LittleBlueTooth.xcodeproj \
  -scheme LittleBlueTooth \
  -configuration ${BUILD_CONFIGURATION} \
  -archivePath ${WATCH_SIMULATOR_ARCHIVE_PATH} \
  -sdk watchsimulator \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

  printf "\n"
  printf "\n"
  echo "watchOS Simulator xcarchive"
  xcodebuild archive \
  -project LittleBlueTooth.xcodeproj \
  -scheme LittleBlueTooth \
  -configuration ${BUILD_CONFIGURATION} \
  -archivePath ${WATCH_DEVICE_ARCHIVE_PATH} \
  -sdk watchos \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

  printf "\n"
  printf "\n"
  echo "macOS catalyst xcarchive"
  xcodebuild archive \
  -project LittleBlueTooth.xcodeproj \
  -scheme LittleBlueTooth \
  -configuration ${BUILD_CONFIGURATION} \
  -archivePath ${CATALYST_ARCHIVE_PATH} \
  -sdk macosx \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  SUPPORTS_MACCATALYST=YES

  printf "\n"
  printf "\n"
  echo "Cleaning up old framework"
  rm -rf "${OUTPUT_FRAMEWORK_PATH}"

  printf "\n"
  printf "\n"
  echo "Getting DWARFDUMP UUID"
  # dump is made by a string we need only the first part UUID: 28FF8530-4C33-3F19-921E-748BF9DEE98D (arm64) LittleBlueTooth.framework.dSYM/Contents/Resources/DWARF/LittleBlueTooth
  IOS_UUID=$(dwarfdump --uuid ${IOS_DEVICE_ARCHIVE_PATH}/dSYMs/${SCHEME_NAME}.framework.dSYM)
  TVOS_UUID=$(dwarfdump --uuid ${TV_DEVICE_ARCHIVE_PATH}/dSYMs/${SCHEME_NAME}.framework.dSYM)
  WATCHOS_UUID=$(dwarfdump --uuid ${WATCH_DEVICE_ARCHIVE_PATH}/dSYMs/${SCHEME_NAME}.framework.dSYM)
  echo "IOS UUID: ${IOS_UUID}"
  echo "TVOD UUID: ${TVOS_UUID}"
  echo "WATCHOS UUID: ${WATCHOS_UUID}"
  #SPLITTING
  iosArray=($IOS_UUID)
  tvosArray=($TVOS_UUID)
  watchosArray=($WATCHOS_UUID)
  IOS_UUID=${iosArray[1]}
  TVOS_UUID=${tvosArray[1]}
  WATCHOS_UUID=${watchosArray[1]}
  echo "IOS UUID: ${IOS_UUID}"
  echo "TVOS UUID: ${TVOS_UUID}"
  echo "WATCHOS UUID: ${WATCHOS_UUID}"

  printf "\n"
  printf "\n"
  echo "Creating xcframworks"
  xcodebuild -create-xcframework \
  -framework ${IOS_SIMULATOR_ARCHIVE_PATH}/Products/Library/Frameworks/${SCHEME_NAME}.framework \
  -debug-symbols ${IOS_SIMULATOR_ARCHIVE_PATH}/dSYMs/${SCHEME_NAME}.framework.dSYM \
  -framework ${IOS_DEVICE_ARCHIVE_PATH}/Products/Library/Frameworks/${SCHEME_NAME}.framework \
  -debug-symbols ${IOS_DEVICE_ARCHIVE_PATH}/dSYMs/${SCHEME_NAME}.framework.dSYM \
  -framework ${TV_SIMULATOR_ARCHIVE_PATH}/Products/Library/Frameworks/${SCHEME_NAME}.framework \
  -debug-symbols ${TV_SIMULATOR_ARCHIVE_PATH}/dSYMs/${SCHEME_NAME}.framework.dSYM \
  -framework ${TV_DEVICE_ARCHIVE_PATH}/Products/Library/Frameworks/${SCHEME_NAME}.framework \
  -debug-symbols ${TV_DEVICE_ARCHIVE_PATH}/dSYMs/${SCHEME_NAME}.framework.dSYM \
  -framework ${WATCH_SIMULATOR_ARCHIVE_PATH}/Products/Library/Frameworks/${SCHEME_NAME}.framework \
  -debug-symbols ${WATCH_SIMULATOR_ARCHIVE_PATH}/dSYMs/${SCHEME_NAME}.framework.dSYM \
  -framework ${WATCH_DEVICE_ARCHIVE_PATH}/Products/Library/Frameworks/${SCHEME_NAME}.framework \
  -debug-symbols ${WATCH_DEVICE_ARCHIVE_PATH}/dSYMs/${SCHEME_NAME}.framework.dSYM \
  -framework ${CATALYST_ARCHIVE_PATH}/Products/Library/Frameworks/${SCHEME_NAME}.framework \
  -debug-symbols ${CATALYST_ARCHIVE_PATH}/dSYMs/${SCHEME_NAME}.framework.dSYM \
  -output ${OUTPUT_FRAMEWORK_PATH}/${FRAMEWORK_NAME}.xcframework

  printf "\n"
  printf "\n"
  echo "Copying dSYMs"
  cp -a ${IOS_SIMULATOR_ARCHIVE_PATH}/dSYMs/. ${OUTPUT_FRAMEWORK_PATH}/${FRAMEWORK_NAME}-dSYMs-iphonesimulator
  cp -a ${IOS_DEVICE_ARCHIVE_PATH}/dSYMs/. ${OUTPUT_FRAMEWORK_PATH}/${FRAMEWORK_NAME}-dSYMs-iphoneos
  cp -a ${TV_SIMULATOR_ARCHIVE_PATH}/dSYMs/. ${OUTPUT_FRAMEWORK_PATH}/${FRAMEWORK_NAME}-dSYMs-appletvsimulator
  cp -a ${TV_DEVICE_ARCHIVE_PATH}/dSYMs/. ${OUTPUT_FRAMEWORK_PATH}/${FRAMEWORK_NAME}-dSYMs-appletvos
  cp -a ${WATCH_SIMULATOR_ARCHIVE_PATH}/dSYMs/. ${OUTPUT_FRAMEWORK_PATH}/${FRAMEWORK_NAME}-dSYMs-watchsimulator
  cp -a ${WATCH_DEVICE_ARCHIVE_PATH}/dSYMs/. ${OUTPUT_FRAMEWORK_PATH}/${FRAMEWORK_NAME}-dSYMs-watchos
  cp -a ${CATALYST_ARCHIVE_PATH}/dSYMs/. ${OUTPUT_FRAMEWORK_PATH}/${FRAMEWORK_NAME}-dSYMs-macosx

  printf "\n"
  printf "\n"
  echo "logs successfully written out to:"
  echo $(pwd)/XCFrameworkLogs.txt

}

performXCFramework() {
  printf "\n"
  printf "\n"
  makeXCFramework "LittleBlueTooth" "Release" | tee XCFrameworkLogs.txt
}

main() {
  echo " ╔═══════════════════════════════════╗"
  echo " ║ Make LittleBlueTooth XCFramework! ║"
  echo " ╚═══════════════════════════════════╝"

  performXCFramework

  echo " ╔═══════╗"
  echo " ║ Done! ║"
  echo " ╚═══════╝"
}

################################################################################

clear
main
