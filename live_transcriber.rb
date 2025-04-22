# Quick run instructions, export OPENAI_API_KEY=""
# run: live_transcriber.rb

require 'net/http'
require 'm3u8'
require 'openai'
require 'uri'
require 'listen'
require 'logger'
require 'fileutils'
require 'json'
require 'time'

require './spanish_transcriber'

class LiveTranscriber
  def initialize(stream_url = nil)
    @obs_stream = true
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    @transcriber = SpanishTranscriber.new(project_name: 'live')

    @openapikey = ENV.fetch('OPENAI_API_KEY', nil)
    raise Exception.new 'Please place your OpenAI API key in the environment at OPENAI_API_KEY' unless @openapikey

    @logger.info 'OpenAI API key read'
    @client = OpenAI::Client.new(access_token: @openapikey)

    if stream_url
      @stream_url = stream_url
      @logger.info "Stream URL read: #{@stream_url}" if @stream_url
      @obs_stream = false
    end

    @running = false
    @segment_buffer = []
    @transcriptions = []
    @callback = nil
  end

  def start
    @running = true

    begin
      if @obs_stream
        process_local_stream
      else
        process_stream_from_url
      end
    rescue StandardError => e
      @logger.error("Error: #{e.message}")
      @logger.error(e.backtrace.join("\n"))
    end
  end

  def stop
    @running = false
  end

  def on_transcription(&block)
    @callback = block
  end

  private

  def process_local_stream
    listener = Listen.to('live_audio') do |modified, _added, _removed|
      modified.each do |file|
        next unless @transcriber.valid_audio_file?(file)

        @logger.info("New file detected: #{file}")
        @transcriber.process_file(file)
      end
    end

    listener.start
    @logger.info("Watching live_audio/ directory")
    sleep
  end

  def process_stream_from_url
    @logger.info("Starting transcription from: #{@stream_url}")

    base_uri = URI(@stream_url)
    base_url = "#{base_uri.scheme}://#{base_uri.host}:#{base_uri.port}#{File.dirname(base_uri.path)}"

    while @running
      playlist_content = download_content(@stream_url)
      @logger.info "Playlist Content: #{playlist_content}"

      playlist = M3u8::Playlist.read(playlist_content)
      @logger.info "Playlist: #{playlist}"

      segments = playlist.items.select { |item| item.is_a?(M3u8::SegmentItem) }
      segments.each do |segment|
        segment_url = if segment.segment.start_with?('http')
                        segment.segment
                      else
                        "#{base_url}#{segment.segment}"
                      end
        @logger.info "Segment: #{segment_url}"

        next if @segment_buffer.include?(segment_url)

        @segment_buffer << segment_url
        @segment_buffer.shift if @segment_buffer.size > 100

        segment_data = download_content(segment_url)

        process_chunk(segment_data, segment_url) if segment_data && !segment_data.empty?
      end

      break unless @running

      sleep 2 # seems a bit arbitary
    end
  end

  def download_content(url)
    uri = URI(url)
    response = Net::HTTP.get_response(uri)

    if response.is_a?(Net::HTTPSuccess)
      response.body
    else
      @logger.error("Failed to download: #{url}: #{response.code}")
      nil
    end
  end

  def process_chunk(audio_data, segment_url)
    FileUtils.mkdir_p('live_audio') unless Dir.exist?('live_audio')
    temp_file = File.open(File.join('live_audio', "audio_segment_#{Time.now.to_i}.aac"), 'wb')

    begin
      temp_file.binmode
      temp_file.write(audio_data)
      temp_file.flush
      temp_file.rewind

      if File.exist?(temp_file.path) && File.size(temp_file.path) > 1024
        @logger.info("chunk saved at: #{temp_file.path}, size: #{File.size(temp_file.path)}")
      else
        @logger.error("Audio file missing or too small: #{temp_file.path}")
        raise "Failed to save audio file: #{temp_file.path} (size: #{begin
          File.size(temp_file.path)
        rescue StandardError
          'unknown'
        end})"
      end

      # Transcribe audio if needed
      handle_transcription(transcribe_audio(temp_file.path), segment_url)
    ensure
      temp_file.close
      begin
        File.unlink(temp_file.path)
      rescue StandardError
        # Delete the file, ignore errors if it fails
        nil
      end
    end
  end

  def transcribe_audio(audio_file_path)
    @logger.info "Transcribe File: #{audio_file_path}"
    transcription = @transcriber.process_file(audio_file_path)
    @logger.info "Transcription: #{transcription}"

    transcription
  end

  def handle_transcription(transcription, segment_url)
    if transcription.nil?
      @logger.info('Is nil')
    elsif transcription.is_a? Array
      @logger.info("Is array, not string: #{transcription}")
    elsif (transcription.is_a? String) && transcription.strip.empty?
      @logger.info('Empty string')
    else
      process_transcription(transcription, segment_url)
    end
  end

  def process_transcription(transcription, segment_url)
    timestamp = Time.now.strftime('%H:%M:%S')
    @logger.info("#{timestamp} | Transcription: #{transcription}")

    result = {
      timestamp: timestamp,
      segment_url: segment_url,
      text: transcription
    }

    @transcriptions << result
    @callback&.call(result)
  end
end

if __FILE__ == $PROGRAM_NAME
  lt = LiveTranscriber.new
  lt.start
end
