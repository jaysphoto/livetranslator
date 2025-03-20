# inititate
require 'openai'
require 'open_api_client_rspec'


# Test
# initializing the OpenAI 
describe "OpenAPI Client" do
    let(:stream_url) { "http://stream_url" }
    
    before do
        # Mock environment variable
        allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("mock_api_key")
        
        # Mock OpenAI client
    end

    it "initializes the OpenAI client if the API key is set" do
        mock_client = class_double(OpenAI::Client)
        expect(mock_client).to receive(:new).with(access_token: "mock_api_key")
        mock_client.new(access_token: "api_access_key")
    end

    it "initializes the OpenAI client if the API key is set" do
        expect(OpenAI::Client).to receive(:new).with(access_token: "mock_api_key")
    end
end 