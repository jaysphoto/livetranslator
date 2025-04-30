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
  def initialize(stream_uri = nil)
    $stdout.sync = true
    @logger = Logger.new($stdout)
    @logger.level = Logger::INFO
    @source = if stream_uri.nil?
                require './lib/streams/filesystem'
                Streams::Filesystem.new
              else
                require './lib/streams/hls'
                Streams::HLS.new stream_uri
              end
    @transcriber = SpanishTranscriber.new(project_name: 'live', logger: @logger)
    @transcriptions = []
    @callback = nil

    @running = false
  end

  def start
    @running = true

    while @running
      begin
        process
        sleep 2 # seems a bit arbitary
      rescue StandardError => e
        @logger.error("Error: #{e.message}")
        @logger.error(e.backtrace.join("\n"))
      end
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
    listener = Listen.to('live_audio', &file_change_callback)
    listener.start

    @logger.info('Listening for new files in live_audio/ directory')

    while @running
      sleep 2 # seems a bit arbitary
    end
  end

  def file_change_callback
    proc do |modified|
      modified.each do |file|
        next unless @transcriber.valid_audio_file?(file)

        @logger.info("New file detected: #{file}")
        handle_transcription(transcribe_audio(file), file)
      end
    end
  end

  def process_chunk(audio_data, segment_uri)
    temp_file = File.open(File.join('live_audio', "audio_segment_#{Time.now.to_i}.aac"), 'wb').binmode
    begin
      # Write and transcribe audio if needed
      write_audio_data(temp_file, audio_data)
      handle_transcription(transcribe_audio(temp_file.path), segment_uri)
    ensure
      temp_file.close
      begin
        File.unlink(temp_file.path)
      rescue StandardError
        nil # Delete the file, ignore errors if it fails
      end
    end
  end

  def write_audio_data(file, audio_data)
    file.write(audio_data)
    file.flush
    f_size = begin
      File.size(file.path)
    rescue StandardError
      StandardError 'unknown'
    end
    unless File.exist?(file.path) && f_size.is_a?(Integer) && f_size > 1024
      @logger.error("Audio file missing or too small: #{file.path}")
      raise "Failed to save audio file: #{file.path} (size: #{f_size})"
    end
    @logger.info("Chunk saved at: #{file.path}, size: #{f_size}")
  end

  def transcribe_audio(audio_file_path)
    @logger.info "Transcribe File: #{audio_file_path}"
    transcription = @transcriber.process_file(audio_file_path)
    @logger.info "Transcription: #{transcription}"

    transcription
  end

  def handle_transcription(transcription, segment_uri)
    if transcription.nil?
      @logger.info('Is nil')
    elsif transcription.is_a? Array
      @logger.info("Is array, not string: #{transcription}")
    elsif (transcription.is_a? String) && transcription.strip.empty?
      @logger.info('Empty string')
    else
      process_transcription(transcription, segment_uri)
    end
  end

  def process_transcription(transcription, segment_uri)
    timestamp = Time.now.strftime('%H:%M:%S')
    @logger.info("#{timestamp} | Transcription: #{transcription}")

    result = {
      timestamp: timestamp,
      segment_uri: segment_uri,
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
