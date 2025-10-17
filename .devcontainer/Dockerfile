# Flutter development environment with support for web, emulators, and device connections
FROM ghcr.io/cirruslabs/flutter:3.29.0

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    usbutils \
    && rm -rf /var/lib/apt/lists/*

# Install Google Chrome for web development and testing
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# Set working directory (matches devcontainer.json workspaceFolder)
WORKDIR /app

# Copy pubspec files first for better caching
COPY pubspec.yaml pubspec.lock ./

# Get Flutter dependencies (will be cached if pubspec doesn't change)
RUN flutter pub get

# Copy the rest of the project files
COPY . /app

# Enable Flutter web support (if not already enabled)
RUN flutter config --enable-web

# Accept Android SDK licenses
RUN yes | flutter doctor --android-licenses

# Expose port for Flutter web server
EXPOSE 8080

# Default command when container starts
CMD [ "bash" ]