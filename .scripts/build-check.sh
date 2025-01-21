#!/bin/bash

set -e

# Default parameter values
SCHEME=""
IOS_VERSION="latest"
IOS_VERSION_NAME=""
DEVICE_TYPE="iphone"
EXECUTION_TYPE="build"

# Parse input parameters
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --scheme) SCHEME="$2"; shift ;;
    --ios-version) IOS_VERSION="$2"; shift ;;
    --device-type) DEVICE_TYPE="$2"; shift ;;
    --type) EXECUTION_TYPE="$2"; shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# Ensure required parameters are provided
if [ -z "$SCHEME" ]; then
  echo "Error: 'scheme' parameter is required."
  exit 1
fi

# Validate device type
if [[ "$DEVICE_TYPE" != "iphone" && "$DEVICE_TYPE" != "ipad" ]]; then
  echo "Error: 'device-type' must be 'iphone' or 'ipad'."
  exit 1
fi

# Validate execution type
if [[ "$EXECUTION_TYPE" != "build" && "$EXECUTION_TYPE" != "test" ]]; then
  echo "Error: 'type' must be 'build' or 'test'."
  exit 1
fi

# Set device name based on device type
DEVICE_NAME="iPhone 16"
if [ "$DEVICE_TYPE" == "ipad" ]; then
  DEVICE_NAME="iPad Pro 11-inch"
fi

# Fetch available iOS runtimes
echo "Fetching available iOS runtimes..."
AVAILABLE_RUNTIMES=$(xcrun simctl list runtimes | grep -o 'iOS [0-9]*\.[0-9]*')
echo "available iOS runtimes: $AVAILABLE_RUNTIMES"

# Determine iOS version
if [ "$IOS_VERSION" == "latest" ]; then
  IOS_VERSION=$(echo "$AVAILABLE_RUNTIMES" | grep -oE '[0-9]+\.[0-9]+' | sort -Vr | head -n 1)
  IOS_VERSION_NAME="iOS $IOS_VERSION"
fi
echo "Continue for: $IOS_VERSION_NAME"

# Check if the specified runtime is available
if ! echo "$AVAILABLE_RUNTIMES" | grep -q "$IOS_VERSION_NAME"; then
  echo "iOS version $IOS_VERSION is not installed. Downloading..."
  xcodebuild -downloadPlatform iOS -buildVersion "$IOS_VERSION"
#else
#  RUNTIME_FILE_NAME=$(xcodebuild -downloadPlatform iOS -buildVersion $IOS_VERSION -exportPath ./SimulatorRuntimes/ | grep -o 'iphonesimulator[^/]\+$')
#  echo "importing platform from file: $RUNTIME_FILE_NAME"
#  xcodebuild -importPlatform ./SimulatorRuntimes/$RUNTIME_FILE_NAME
fi

# Fetch simulator UUID for the specified runtime and device type
echo "Creating simulator for $DEVICE_NAME ($IOS_VERSION_NAME)..."
SIMULATOR_UUID=$(xcrun simctl list devices "$IOS_VERSION_NAME" | grep "$DEVICE_NAME" | head -n 1 | grep -Eo "[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}")

if [ -z "$SIMULATOR_UUID" ]; then
  echo "No simulator found. Creating a new simulator..."
  
  # Check if the provided DEVICE_NAME exists in the available device types
  AVAILABLE_DEVICE=$(xcrun simctl list devicetypes | grep "$DEVICE_NAME")
  
  if [ -z "$AVAILABLE_DEVICE" ]; then
    echo "Error: Unable to find device matching '$DEVICE_NAME'. Please provide a valid device name."
    echo "Available devices:"
    xcrun simctl list devicetypes
    exit 1
  fi

  # Update DEVICE_NAME to match the first valid entry if necessary
  DEVICE_NAME=$(echo "$AVAILABLE_DEVICE" | head -n 1 | sed -E 's/ \([^()]*\)$//' | xargs)

  # Retrieve the correct DEVICE_TYPE_ID for the updated DEVICE_NAME
  DEVICE_TYPE_ID=$(echo "$AVAILABLE_DEVICE" | head -n 1 | sed -E 's/.* \(([^()]+)\)$/\1/' | xargs)
  
  if [ -z "$DEVICE_TYPE_ID" ]; then
    echo "Error: Failed to retrieve DEVICE_TYPE_ID for $DEVICE_NAME."
    exit 1
  fi
  
  # Format the iOS version correctly for the runtime ID
  FORMATTED_IOS_VERSION=${IOS_VERSION//./-}
  
  # Create a new simulator
  SIMULATOR_UUID=$(xcrun simctl create "Custom $DEVICE_NAME" "$DEVICE_TYPE_ID" "com.apple.CoreSimulator.SimRuntime.iOS-$FORMATTED_IOS_VERSION")
  
  if [ -z "$SIMULATOR_UUID" ]; then
    echo "Error: Failed to create simulator."
    exit 1
  fi
  
  echo "Created simulator with UUID: $SIMULATOR_UUID"
fi

xcodebuild -scheme $SCHEME -destination "id=$SIMULATOR_UUID" -showdestinations

echo "Continue with simulator with UUID: $SIMULATOR_UUID"

# Build or test with xcodebuild
echo "Running xcodebuild for scheme '$SCHEME' with execution type '$EXECUTION_TYPE'..."
if [ "$EXECUTION_TYPE" == "build" ]; then
  xcodebuild -scheme "$SCHEME" -configuration Release -skipMacroValidation
elif [ "$EXECUTION_TYPE" == "test" ]; then
  xcodebuild test -scheme "$SCHEME" -skipMacroValidation -destination "platform=iOS Simulator,id=$SIMULATOR_UUID"
fi

echo "Execution completed successfully."
