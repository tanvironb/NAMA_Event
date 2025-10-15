# Flutter development environment with support for web, emulators, and device connections
FROM cirrusci/flutter:3.19.0

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    usbutils \
    && rm -rf /var/lib/apt/lists/*

# Install Google Chrome for web development and testing
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# Set working directory (matches devcontainer.json workspaceFolder)
WORKDIR /app

# Copy project files into the container
COPY . /app

# Get Flutter dependencies
RUN flutter pub get

# Enable Flutter web support (if not already enabled)
RUN flutter config --enable-web

# Accept Android SDK licenses
RUN yes | flutter doctor --android-licenses

# Expose port for Flutter web server
EXPOSE 8080

# Default command when container starts
CMD [ "bash" ]