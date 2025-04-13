FROM ruby:3.2-slim

# Install system dependencies including FFmpeg
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ffmpeg \
        build-essential \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile and install dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy the rest of the application
COPY . .

# Create directories for audio files and transcripts
RUN mkdir audio transcripts live_audio live_text

# Set environment variables
ENV APP_ENV=production
ENV AUDIO_DIR=/app/live_audio
ENV TRANSCRIPT_DIR=/app/live_text

# Command to run the application
CMD ["/bin/sh", "-c" , "ruby app.rb"]

