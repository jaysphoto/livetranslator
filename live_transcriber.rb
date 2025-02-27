require 'net/http'
require 'm3u8'
require 'openai'
require 'uri'
require 'logger'
require 'tempfile'
require 'json'
require 'time'

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

    @hls_url = stream_url
    @running = false
    @segment_buffer = []
    @transcriptions = []
    @callback = nil
  end

  def start
    @running = true
    @logger.info("Starting transcription from: #{@hls_url}")
    
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
    base_uri = URI(@hls_url)
    base_url = "#{base_uri.scheme}://#{base_uri.host}#{File.dirname(base_uri.path)}"
    
    while @running
      playlist_content = download_content(@hls_url)
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
    temp_file = Tempfile.new(['audio_segment', '.aac'])

    begin
      temp_file.binmode
      temp_file.write(audio_data)
      temp_file.flush
      temp_file.rewind
      
      transcription = transcribe_audio(temp_file.path)
      
      if transcription.nil? || transcription.strip.empty?
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
      temp_file.unlink
    end
  end

  def transcribe_audio(audio_file_path)
    @logger.info "Transcribe File: #{audio_file_path}"  
    
    "Sample transcription"
  end

end