# frozen_string_literal: true

require 'rspec'
require_relative '../display_translation'

RSpec.describe DisplayTranslation do
  # display
  it 'getting latest English(default) translation text' do
    display = described_class.new
    livetext = display.display_live_text
    # continue from HERE
    expect(livetext).not_to be_empty
    expect(livetext).to eq('This is the first time we have seen the father since he was admitted last February 14th.')
  end
end
