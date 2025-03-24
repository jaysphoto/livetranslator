require 'rspec'
require_relative '../display_translation'

RSpec.describe DisplayTranslation do
    # display
    it 'getting latest translation text' do
        display = described_class.new
        livetext = display.display_live_text
        # continue from HERE
        expect(livetext).not_to be_empty
    end

end

