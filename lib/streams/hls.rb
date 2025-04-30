module Streams
  # HTTP Live Streaming implementation
  class HLS < Base
    def initialize(logger, stream_url)
      super.initialize(logger)

      @logger.info("Starting transcription from: #{@stream_url}")

      base_uri = URI(stream_url)
      @base_url = "#{base_uri.scheme}://#{base_uri.host}:#{base_uri.port}#{File.dirname(base_uri.path)}"
      @segment_buffer = []
    end

    def process
      playlist_content = download_content(@stream_url)
      @logger.info "Playlist Content: #{playlist_content}"

      return unless playlist_content

      playlist = M3u8::Playlist.read(playlist_content)
      @logger.info "Playlist: #{playlist}"

      process_playlist(playlist.items, base_url)
    end

    private

    def process_playlist(playlist_items, base_url)
      segments = playlist_items.select { |item| item.is_a?(M3u8::SegmentItem) }
      segments.each do |segment|
        segment_url = (segment.segment.start_with?('http') ? segment.segment : "#{base_url}/#{segment.segment}")
        next if @segment_buffer.include?(segment_url)

        segment_data = download_segment(segment_url)
        process_chunk(segment_data, segment_url) if segment_data && !segment_data.empty?
      end
    end

    def download_segment(segment_uri)
      @logger.info "Segment: #{segment_uri}"

      @segment_buffer << segment_uri
      @segment_buffer.shift if @segment_buffer.size > 100

      download_content(segment_uri)
    end

    def download_content(url)
      uri = URI(url)
      res = Net::HTTP.get_response(uri)

      if res.is_a?(Net::HTTPSuccess)
        res.body
      else
        @logger.error("Failed to download: #{url}: #{res.is_a?(Net::HTTPResponse) ? res.code : 'unknown error'}")
        nil
      end
    end
  end

  def process_chunk(segmentdata, segment_uri)
    File.open(File.join('live_audio', "audio_segment_#{Time.now.to_i}.aac"), 'wb').binmode
  end
end
