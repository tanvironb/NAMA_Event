# Example: Flutter 3.19.0 (change as needed)
FROM cirrusci/flutter:3.19.0

# Set working directory
WORKDIR /events_app_trueattempt

# Copy project files into the container
COPY . /events_app_trueattempt

# Get dependencies
RUN flutter pub get

# Expose port for web builds (optional)
EXPOSE 8080

# Default command when container starts
CMD [ "bash" ]