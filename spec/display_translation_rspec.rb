require 'rspec'
#require 'openai'
require_relative '../display_translation'

RSpec.describe DisplayTranslation do
    # display
    it 'getting latest translation text' do
       # expect(transcriber).to receive(:convert_mp4_to_mp3).and_call_original
       # expect(transcriber).to receive(:system).and_return(true)
       # expect(transcriber).to receive(:file_properties).with(mp3_file).and_return({})
       #   transcriber.transcribe_pending_files
        display = DisplayTranslation.new
        livetext= display.display_live_text
        # continue from HERE
        expect(livetext).not_to ? be_empty
    end

    

end

