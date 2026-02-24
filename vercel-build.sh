#!/bin/bash

# Clone the flutter repo (shallow clone for speed)
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# Add flutter to path
export PATH="$PATH:`pwd`/flutter/bin"

# Run doctor to ensure everything is correct
flutter doctor

# Enable web support (if not already enabled)
flutter config --enable-web

# Build the project
flutter build web --release
