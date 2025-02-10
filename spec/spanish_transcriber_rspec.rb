require 'fileutils'
require 'openai'
require_relative '../spanish_transcriber'

RSpec.describe SpanishTranscriber do
  let(:project_name) { "test" }
  let(:transcriber) { described_class.new(project_name: project_name) }
  let(:audio_dir) { "#{project_name}_audio" }
  let(:text_dir) { "#{project_name}_text" }
  let(:mp4_file) { File.join(audio_dir, "test.mp4") }
  let(:mp3_file) { File.join(audio_dir, "test.mp3") }
  let(:client_double) { instance_double(OpenAI::Client) }
  let(:audio_double) { instance_double("Audio") }
  let(:mock_response) { { "text" => "Transcribed text" } }

  before do
    FileUtils.mkdir_p(audio_dir)
    FileUtils.mkdir_p(text_dir)
    File.write(mp4_file, "fake mp4 data")

    allow(OpenAI::Client).to receive(:new).and_return(client_double)
    allow(client_double).to receive(:audio).and_return(audio_double)
    allow(audio_double).to receive(:translate).with(hash_including(:model, :file)).and_return(mock_response)
  end

  after do
    FileUtils.rm_rf(audio_dir)
    FileUtils.rm_rf(text_dir)
  end

  it "converts MP4 to MP3 before processing" do
    expect(transcriber).to receive(:convert_mp4_to_mp3).and_call_original
    transcriber.transcribe_pending_files
  end

  it "handles missing ffmpeg gracefully" do
    allow(transcriber).to receive(:system).and_return(false) # Simulate ffmpeg failure
    File.delete(mp3_file) if File.exist?(mp3_file) # Ensure clean state

    transcriber.transcribe_pending_files

    expect(File).not_to exist(mp3_file) # MP3 should not be created
  end
end
