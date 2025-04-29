require 'fileutils'
require_relative '../spanish_transcriber'

RSpec.describe SpanishTranscriber do
  subject(:transcriber) { described_class.new(project_name: project_name, logger: logger) }

  let(:project_name) { 'test' }
  let(:audio_dir) { "#{project_name}_audio" }
  let(:text_dir) { "#{project_name}_text" }
  let(:openai_stub) { instance_double(TranscriberOpenAI) }
  let(:logger) { Logger.new($stdout) }

  before do
    # Instance stubs
    allow(TranscriberOpenAI).to receive(:new).and_return(openai_stub)
    allow(openai_stub).to receive(:transcribe_audio)
    allow(openai_stub).to receive(:translate_text)
    # Mock IO calls
    allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return(openai_api_key)
    allow(FileUtils).to receive(:mkdir_p)
    allow(Dir).to receive(:glob).with("#{audio_dir}/*").and_return([mp4_file])
    allow(File).to receive_messages(ctime: 10, size: 2048, write: true)
  end

  it 'creates the audio and text directories', :aggregate_failures do
    transcriber # Instantiate, subjects are lazy-loading

    expect(FileUtils).to have_received(:mkdir_p).with(audio_dir)
    expect(FileUtils).to have_received(:mkdir_p).with(text_dir)
  end

  it 'converts MP4 to MP3 before processing' do
    allow(Kernel).to receive(:system).and_return(true)

    transcriber.transcribe_pending_files
    expect(openai_stub).to have_received(:transcribe_audio).once.with(mp3_file)
  end

  it 'handles missing ffmpeg gracefully' do
    allow(Kernel).to receive(:system).and_return(false) # Simulate ffmpeg failure

    transcriber.transcribe_pending_files
    expect(openai_stub).not_to have_received(:transcribe_audio)
  end

  # Helper methods to provide test data
  def openai_api_key
    'mock_openapi_ai_key'
  end

  def mp3_file
    File.join(audio_dir, 'test.mp3')
  end

  def mp4_file
    File.join(audio_dir, 'test.mp4')
  end
end
