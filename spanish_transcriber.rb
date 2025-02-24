require 'fileutils'
require 'openai'
require 'logger'

class SpanishTranscriber
  SUPPORTED_AUDIO_FORMATS = %w[mp3 ogg wav mp4].freeze
  MAX_RETRIES = 3
  RETRY_DELAY = 2 # Initial delay in seconds, increases exponentially

  def initialize(project_name: "", translate_audio: true)
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::DEBUG
    @project_name = project_name.empty? ? "" : "#{project_name}_"
    @audio_dir = "#{@project_name}audio"
    @text_dir = "#{@project_name}text"
    @translate_audio = translate_audio
    @openapikey = ENV["OPENAI_API_KEY"]
    if @openapikey
      @logger.info "OpenAI API key set"
      @client = OpenAI::Client.new(access_token: @openapikey)
    else
      raise Exception.new "Please place your OpenAI API key in the environment at OPENAI_API_KEY"
    end

    FileUtils.mkdir_p(@audio_dir)
    FileUtils.mkdir_p(@text_dir)
  end

  def transcribe_pending_files
    @logger.info("Scanning #{@audio_dir} for audio files...")
    audio_files = Dir.glob(File.join(@audio_dir, "*")).select { |f| valid_audio_file?(f) }

    if audio_files.empty?
      @logger.warn("No audio files found!")
      return
    end

    audio_files.each do |file|
      process_file(file)
    end
  end

  private

  def valid_audio_file?(file)
    ext = File.extname(file).downcase.delete_prefix('.')
    if SUPPORTED_AUDIO_FORMATS.include?(ext)
      true
    else
      @logger.warn("Skipping unsupported file format: #{file}")
      false
    end
  end

  def process_file(file)
    ext = File.extname(file).downcase
    base_name = File.basename(file, ext)
    spanish_file = File.join(@text_dir, "#{base_name}_ES.txt")
    english_file = File.join(@text_dir, "#{base_name}_EN.txt")

    if File.exist?(english_file) && File.exist?(spanish_file)
      @logger.info("Skipping #{file}, already transcribed and translated.")
      return
    end

    file = convert_mp4_to_mp3(file) if ext == ".mp4"
    return unless file # Skip if conversion failed

    transcribe_then_translate(file, spanish_file, english_file)
  end

  def convert_mp4_to_mp3(mp4_file)
    mp3_file = mp4_file.sub(/\.mp4$/, '.mp3')
    return mp3_file if File.exist?(mp3_file) # Already converted

    @logger.info("Converting #{mp4_file} to MP3...")
    result = system("ffmpeg -i '#{mp4_file}' -q:a 3 '#{mp3_file}' 2>/dev/null")

    if result
      @logger.info("Successfully converted to #{mp3_file}")
      mp3_file
    else
      @logger.error("Failed to convert #{mp4_file} to MP3. Is ffmpeg installed?")
      nil
    end
  end

  def transcribe_then_translate(file, spanish_file, english_file)
    transcription = transcribe_audio(file)
    return unless transcription

    # Save Spanish transcription
    File.write(spanish_file, transcription)
    @logger.info("Saved Spanish transcription to #{spanish_file}")

    if @translate_audio && !File.exist?(english_file)
      translation = translate_text(transcription)
      @logger.info("Translation: #{translation}")
      return unless translation
      File.write(english_file, translation)
      @logger.info("Saved English translation to #{english_file}")
    end
  end

  def transcribe_audio(file)
    @logger.info("Transcribing #{file}...")

    retries = 0
    begin
      response = @client.audio.transcribe(
        parameters: {
          model: "whisper-1",
          file: File.open(file, "rb"),
          response_format: "text"
        }
      )
      @logger.debug("Transcription response: #{response.inspect}")

      if response.nil? || response.empty?
          @logger.warn("No text transcribed for #{file}.")
          return nil
      end

      return response
    rescue Faraday::ServerError => err # HTTP 500
      if retries < MAX_RETRIES
        delay = RETRY_DELAY**(retries + 1)
        @logger.warn("Server error (500) during transcription of #{file}. Retrying in #{delay} seconds... (Attempt #{retries + 1}/#{MAX_RETRIES})")
        sleep(delay)
        retries += 1
        retry
      else
        @logger.error("Persistent server error (500) for #{file}. Skipping after #{MAX_RETRIES} retries.")
      end
    rescue Faraday::BadRequestError => err
      @logger.error("Bad request error during transcription: #{err.message}")
      @logger.error("This usually means the API rejected our request format")
    rescue OpenAI::Error => err
      log_api_error(err, file, "transcription")
    rescue => err
      log_generic_error(err, file, "transcription")
    end

    nil
  end

  def translate_text(text)
    @logger.info("Translating text...")

    retries = 0
    begin
      response = @client.chat(
        parameters: {
          model: "gpt-4",
          messages: [
            { role: "system", content: "You are a translator. Translate the following Spanish text to English, maintaining the original meaning and tone." },
            { role: "user", content: text }
          ]
        }
      )
      return response.dig("choices", 0, "message", "content")
    rescue Faraday::ServerError => err # HTTP 500
      if retries < MAX_RETRIES
        delay = RETRY_DELAY**(retries + 1)
        @logger.warn("Server error (500) during translation. Retrying in #{delay} seconds... (Attempt #{retries + 1}/#{MAX_RETRIES})")
        sleep(delay)
        retries += 1
        retry
      else
        @logger.error("Persistent server error (500) for translation. Skipping after #{MAX_RETRIES} retries.")
      end
    rescue Faraday::BadRequestError => err
      @logger.error("Bad request error during translation: #{err.message}")
      @logger.error("This usually means the API rejected our request format")
    rescue OpenAI::Error => err
      log_api_error(err, "text", "translation")
    rescue => err
      log_generic_error(err, "text", "translation")
    end

    nil
  end

  def log_api_error(error, item, action)
    @logger.error("API Error during #{action} for #{item}: #{error.message}")

    if error.response
      @logger.error("HTTP Code: #{error.response.status}")
      @logger.error("Response Headers: #{error.response.headers}")
      @logger.error("Response Body: #{error.response.body}")
    end

    @logger.error("❌ Authentication issue: Check your OpenAI API key!") if error.message.include?("401")
  end

  def log_generic_error(error, item, action)
    @logger.error("Unexpected error during #{action} for #{item}: #{error.class} - #{error.message}")
    @logger.debug(error.backtrace.join("\n"))
  end
end

# Run transcriber
transcriber = SpanishTranscriber.new
transcriber.transcribe_pending_files