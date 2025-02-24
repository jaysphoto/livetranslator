# Spanish Audio Transcriber

## Setup
```bash
bundle install
```

## Usage
1. Place audio files in the `/audio` directory
2. Receive Spanish transcription and English translation in `/text` directory

## Running the Script (After Setup)
```bash
ruby spanish_transcriber.rb
```

## Dependencies
- Valid `OPENAI_API_KEY` set as an environment variable
- `ffmpeg` installed (required for MP4 to MP3 conversion - not needed if only using MP3/ogg/wav files)

## Features
- Processes MP3, OGG, and MP4 files
- Converts MP4 to MP3 using ffmpeg (with error handling)
- Transcribes audio and translates it to English (default)
- Supports batch processing with configurable project name
- Ensures already processed files are skipped
- Includes logging for debugging

## Troubleshooting

### Check OpenAI API Key
```bash
curl https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
     "model": "gpt-4",
     "messages": [{"role": "user", "content": "Say this is a test!"}],
     "temperature": 0.7
   }'
```

### Check Transcription
```bash
curl --request POST \
  --url https://api.openai.com/v1/audio/transcriptions \
  --header "Authorization: Bearer $OPENAI_API_KEY" \
  --header 'Content-Type: multipart/form-data' \
  --form file=@./audio/amelia.mp3 \
  --form model=whisper-1
```