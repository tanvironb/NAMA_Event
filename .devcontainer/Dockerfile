# Flutter development environment with support for web, emulators, and device connections
FROM ghcr.io/cirruslabs/flutter:3.29.1

# --- Fix all Ubuntu mirrors (archive + security + updates)
RUN sed -i 's|http://archive.ubuntu.com/ubuntu/|http://sg.archive.ubuntu.com/ubuntu/|g' /etc/apt/sources.list \
 && sed -i 's|http://security.ubuntu.com/ubuntu|http://sg.archive.ubuntu.com/ubuntu|g' /etc/apt/sources.list

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    usbutils \
    ca-certificates \
    apt-transport-https \
    && rm -rf /var/lib/apt/lists/*

# --- Reliable Chrome installation
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable fonts-liberation xdg-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . /app
RUN flutter config --enable-web
RUN yes | flutter doctor --android-licenses
EXPOSE 8080
CMD [ "bash" ]
