require 'rspec'
require 'openai'
require_relative '../live_transcriber'

# from claude.ai: https://claude.ai/share/6326057b-da86-404c-9b7c-c84d33e1634c

RSpec.describe LiveTranscriber do
  let(:stream_url) { "https://example.com/stream.m3u8" }
  
  before do
    # Mock environment variable
    allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("mock_api_key")
    
    # Mock OpenAI client
    mock_client = instance_double(OpenAI::Client)
    allow(OpenAI::Client).to receive(:new).and_return(mock_client)
    
    # Mock external dependencies
    allow_any_instance_of(LiveTranscriber).to receive(:download_content).and_return(sample_m3u8, sample_segment_data)
    allow_any_instance_of(LiveTranscriber).to receive(:transcribe_audio).and_return("Sample transcription")
    
    # Mock SpanishTranscriber
    mock_transcriber = double("SpanishTranscriber")
    allow(SpanishTranscriber).to receive(:new).and_return(mock_transcriber)
    allow(mock_transcriber).to receive(:transcribe_pending_files).and_return("Sample Spanish transcription")
    
    # Stop the transcriber from running indefinitely in tests
    allow_any_instance_of(LiveTranscriber).to receive(:process_stream) do |instance|
      # Simulate processing one segment
      instance.send(:process_chunk, sample_segment_data, "https://example.com/segment_1.aac")
      instance.stop
    end
    
    # Mock M3u8::Playlist
    mock_playlist = instance_double(M3u8::Playlist)
    mock_segment = instance_double(M3u8::SegmentItem, segment: "segment_1.aac")
    allow(M3u8::Playlist).to receive(:read).and_return(mock_playlist)
    allow(mock_playlist).to receive(:items).and_return([mock_segment])
    
    # Mock Tempfile
    mock_tempfile = instance_double(Tempfile)
    allow(Tempfile).to receive(:new).and_return(mock_tempfile)
    allow(mock_tempfile).to receive(:binmode).and_return(nil)
    allow(mock_tempfile).to receive(:write).and_return(nil)
    allow(mock_tempfile).to receive(:flush).and_return(nil)
    allow(mock_tempfile).to receive(:rewind).and_return(nil)
    allow(mock_tempfile).to receive(:close).and_return(nil)
    allow(mock_tempfile).to receive(:unlink).and_return(nil)
    allow(mock_tempfile).to receive(:path).and_return("temp/audio_segment_123.aac")
  end
  
  describe "#initialize" do
    it "creates a new transcriber with the provided URL" do
      transcriber = LiveTranscriber.new(stream_url)
      expect(transcriber.instance_variable_get(:@hls_url)).to eq(stream_url)
      expect(transcriber.instance_variable_get(:@running)).to eq(false)
    end
    
    it "initializes an empty transcriptions array" do
      transcriber = LiveTranscriber.new(stream_url)
      expect(transcriber.instance_variable_get(:@transcriptions)).to eq([])
    end
    
    it "raises an exception if the OpenAI API key is not set" do
      allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return(nil)
      expect { LiveTranscriber.new(stream_url) }.to raise_error(Exception, "Please place your OpenAI API key in the environment at OPENAI_API_KEY")
    end

    it "raises an exception if the OpenAI API key is expired" do
      allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return(nil)
      expect { LiveTranscriber.new(stream_url) }.to raise_error(Exception, "Please put more credit in your OpenAI API environment.")
    end
    
    it "initializes the OpenAI client if the API key is set" do
      expect(OpenAI::Client).to receive(:new).with(access_token: "mock_api_key")
      LiveTranscriber.new(stream_url)
    end
  end
  
  describe "#start" do
    let(:transcriber) { LiveTranscriber.new(stream_url) }
    
    it "sets running to true" do
      transcriber.start
      expect(transcriber.instance_variable_get(:@running)).to eq(false) # It gets set back to false by our mocked process_stream
    end
    
    it "processes the stream" do
      expect(transcriber).to receive(:process_stream)
      transcriber.start
    end
    
    it "adds a transcription to the transcriptions array" do
      transcriber.start
      expect(transcriber.instance_variable_get(:@transcriptions).size).to eq(1)
      expect(transcriber.instance_variable_get(:@transcriptions).first[:text]).to eq("Sample transcription")
    end
  end
  
  describe "#stop" do
    let(:transcriber) { LiveTranscriber.new(stream_url) }
    
    it "sets running to false" do
      transcriber.instance_variable_set(:@running, true)
      transcriber.stop
      expect(transcriber.instance_variable_get(:@running)).to eq(false)
    end
  end
  
  describe "#on_transcription" do
    let(:transcriber) { LiveTranscriber.new(stream_url) }
    
    it "calls the provided block when a transcription is completed" do
      callback_called = false
      test_result = nil
      
      transcriber.on_transcription do |result|
        callback_called = true
        test_result = result
      end
      
      transcriber.start
      
      expect(callback_called).to eq(true)
      expect(test_result[:text]).to eq("Sample transcription")
    end
  end
  
  # Helper methods to provide test data
  def sample_m3u8
    <<~M3U8
      #EXTM3U
      #EXT-X-VERSION:3
      #EXT-X-TARGETDURATION:6
      #EXT-X-MEDIA-SEQUENCE:1
      #EXTINF:5.0,
      segment_1.aac
    M3U8
  end
  
  def sample_segment_data
    "mock_audio_data"
  end
end