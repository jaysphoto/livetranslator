require "openai"
require "fileutils"
require "logger"

class SpanishTranscriber
  AUDIO_DIR = "audio"
  TEXT_DIR = "text"

  def initialize
    @client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
    @logger = Logger.new($stdout)
    @logger.level = Logger::INFO
  end

  def transcribe_pending_files
    ensure_directories_exist

    convert_mp4_files

    audio_files = Dir.glob("#{AUDIO_DIR}/*.mp3") + Dir.glob("#{AUDIO_DIR}/*.wav")
    @logger.info("Found #{audio_files.size} audio file(s) to process.")

    audio_files.each do |audio_file|
      text_file = "#{TEXT_DIR}/#{File.basename(audio_file, '.*')}.txt"

      if File.exist?(text_file)
        @logger.info("Skipping already transcribed file: #{text_file}")
        next
      end

      @logger.info("Processing: #{audio_file}")
      transcribed_text = transcribe_audio(audio_file)

      if transcribed_text
        File.write(text_file, transcribed_text)
        @logger.info("Transcription saved: #{text_file}")
      else
        @logger.warn("Failed to transcribe: #{audio_file}")
      end
    end
  end

  private

  def ensure_directories_exist
    FileUtils.mkdir_p(AUDIO_DIR)
    FileUtils.mkdir_p(TEXT_DIR)
  end

  def convert_mp4_files
    mp4_files = Dir.glob("#{AUDIO_DIR}/*.mp4")
    return if mp4_files.empty?

    @logger.info("Found #{mp4_files.size} MP4 file(s) - converting to MP3.")

    mp4_files.each do |mp4_file|
      mp3_file = "#{File.dirname(mp4_file)}/#{File.basename(mp4_file, '.*')}.mp3"
      
      unless File.exist?(mp3_file)
        @logger.info("Converting #{mp4_file} to MP3...")
        system("ffmpeg -i \"#{mp4_file}\" -q:a 2 -acodec libmp3lame \"#{mp3_file}\"")
      else
        @logger.info("MP3 version already exists: #{mp3_file}")
      end
    end
  end

  def transcribe_audio(audio_file)
    @logger.info("Sending #{audio_file} to OpenAI for transcription...")
    response = @client.audio.transcribe(
      parameters: {
        model: "whisper-1",
        file: File.open(audio_file, "rb"),
        language: "es"
      }
    )

    if response["text"]
      @logger.info("Transcription successful for #{audio_file}")
      response["text"]
    else
      @logger.error("Unexpected response from OpenAI: #{response.inspect}")
      nil
    end
  end
end

if __FILE__ == $0
  transcriber = SpanishTranscriber.new
  transcriber.transcribe_pending_files
end
