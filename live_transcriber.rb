# Quick run instructions, export OPENAI_API_KEY=""
# enter irb and run the below
# require './live_transcriber'
# stream = "https://rtvelivesrc2.rtve.es/live-origin/24h-hls/bitrate_3.m3u8"
# lt = LiveTranscriber.new stream
# lt.start

require 'net/http'
require 'm3u8'
require 'openai'
require 'uri'
require 'logger'
require 'fileutils'
require 'json'
require 'time'

require './spanish_transcriber'

class LiveTranscriber  

  def initialize(stream_url)
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO

    @openapikey = ENV["OPENAI_API_KEY"]
    if @openapikey
      @logger.info "OpenAI API key read"
      @client = OpenAI::Client.new(access_token: @openapikey)
    else
      raise Exception.new "Please place your OpenAI API key in the environment at OPENAI_API_KEY"
    end

    @stream_url = stream_url
    if @stream_url
      @logger.info "Stream URL read: #{@stream_url}"
    end

    @running = false
    @segment_buffer = []
    @transcriptions = []
    @callback = nil
  end

  def start
    @running = true
    @logger.info("Starting transcription from: #{@stream_url}")
    
    begin
      process_stream
    rescue => err
      @logger.error("Error: #{err.message}")
      @logger.error(err.backtrace.join("\n"))
    end
  end

  def stop
    @running = false
  end
  
  def on_transcription(&block)
    @callback = block
  end

  private

  def process_stream
    base_uri = URI(@stream_url)
    base_url = "#{base_uri.scheme}://#{base_uri.host}#{File.dirname(base_uri.path)}"
    
    while @running
      playlist_content = download_content(@stream_url)
      @logger.info "Playlist Content: #{playlist_content}"
      
      playlist = M3u8::Playlist.read(playlist_content)
      @logger.info "Playlist: #{playlist}"
      
      segments = playlist.items.select { |item| item.is_a?(M3u8::SegmentItem) }
      
      segments.each do |segment|
        break unless @running
        
        segment_url = segment.segment.start_with?('http') ? 
                      segment.segment : 
                      "#{base_url}/#{segment.segment}"
        @logger.info "Segment: #{segment_url}"

        next if @segment_buffer.include?(segment_url)
        
        @segment_buffer << segment_url
        @segment_buffer.shift if @segment_buffer.size > 100
        
        segment_data = download_content(segment_url)
        
        if segment_data && !segment_data.empty?
          process_chunk(segment_data, segment_url)
        end
      end
      
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
    temp_file = File.open(File.join('/tmp', "audio_segment_#{Time.now.to_i}.aac"), 'wb')

    begin
      temp_file.binmode
      temp_file.write(audio_data)
      temp_file.flush
      temp_file.rewind
      
      transcription = transcribe_audio(temp_file.path)
      
      if transcription.nil? 
        @logger.info("Is nil")
        return
      end

      if transcription.is_a? Array
        @logger.info("Is array, not string: #{transcription}")
        return
      end

      if transcription.strip.empty?
        @logger.info("Empty string")
        return
      end
      
      timestamp = Time.now.strftime("%H:%M:%S")
      @logger.info("#{timestamp} | Transcription: #{transcription}")
      
      result = {
        timestamp: timestamp,
        segment_url: segment_url,
        text: transcription
      }
      
      @transcriptions << result
      @callback.call(result) if @callback
      
      return result
    ensure
      temp_file.close
      File.unlink(temp_file.path) rescue nil  # Delete the file, ignore errors if it fails
    end
  end

  def transcribe_audio(audio_file_path)
    @logger.info "Transcribe File: #{audio_file_path}"  
    transcription = SpanishTranscriber.new(project_name: "live").transcribe_pending_files
    # "Sample transcription"
    transcription
  end

end