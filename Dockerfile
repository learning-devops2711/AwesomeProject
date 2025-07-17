# Build Stage
FROM node:18-bullseye AS build

ARG BUILD_TARGET=apk

RUN apt-get update && apt-get install -y \
  openjdk-17-jdk unzip wget ruby ruby-dev build-essential \
  && npm install -g react-native-cli

ENV ANDROID_SDK_ROOT /opt/android-sdk
ENV PATH ${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/emulator

RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools \
  && cd ${ANDROID_SDK_ROOT}/cmdline-tools \
  && wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O tools.zip \
  && unzip tools.zip \
  && mv cmdline-tools latest \
  && yes | sdkmanager --licenses \
  && sdkmanager "platform-tools" "platforms;android-33" "build-tools;33.0.2" "ndk;25.2.9519653"

WORKDIR /app
COPY . .

RUN npm install

# Common output folder
RUN mkdir -p /output

# Bundle
RUN if [ "$BUILD_TARGET" = "bundle" ]; then \
  mkdir -p android/app/src/main/assets && \
  npx react-native bundle \
    --platform android \
    --dev false \
    --entry-file index.js \
    --bundle-output android/app/src/main/assets/index.android.bundle \
    --assets-dest android/app/src/main/res && \
  cp android/app/src/main/assets/index.android.bundle /output/ && \
  cp -r android/app/src/main/res/drawable* /output/ ; fi

# APK
RUN if [ "$BUILD_TARGET" = "apk" ]; then \
  cd android && ./gradlew assembleRelease && \
  cp app/build/outputs/apk/release/app-release.apk /output/ ; fi

# Final (optional)
FROM busybox:uclibc
COPY --from=build /output /output
