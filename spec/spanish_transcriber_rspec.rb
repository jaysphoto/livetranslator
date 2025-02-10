require "rspec"
require "fileutils"
require_relative "../spanish_transcriber"

RSpec.describe SpanishTranscriber do
  let(:mock_response) { { "text" => "Hola, ¿cómo estás?" } }
  let(:audio_file) { "audio/test_audio.mp3" }
  let(:text_file) { "text/test_audio.txt" }

  before do
    allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("fake_api_key")

    FileUtils.mkdir_p("audio")
    FileUtils.mkdir_p("text")
    File.write(audio_file, "fake audio data")

    client_double = instance_double(OpenAI::Client)
    audio_double = instance_double("OpenAI::Audio")

    allow(OpenAI::Client).to receive(:new).and_return(client_double)
    allow(client_double).to receive(:audio).and_return(audio_double)
    allow(audio_double).to receive(:transcribe).and_return(mock_response)
  end

  after do
    File.delete(audio_file) if File.exist?(audio_file)
    File.delete(text_file) if File.exist?(text_file)
  end

  describe "#transcribe_pending_files" do
    it "transcribes an audio file and saves it as a .txt file" do
      transcriber = SpanishTranscriber.new
      transcriber.transcribe_pending_files

      expect(File.exist?(text_file)).to be true
      expect(File.read(text_file)).to eq("Hola, ¿cómo estás?")
    end

    it "skips already transcribed files" do
      File.write(text_file, "Already transcribed text")

      transcriber = SpanishTranscriber.new
      expect { transcriber.transcribe_pending_files }.not_to change { File.read(text_file) }
    end
  end
end
