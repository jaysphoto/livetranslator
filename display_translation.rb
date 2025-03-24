require 'logger'

class DisplayTranslation
    def initialize
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::DEBUG
        @live_text_dir = 'live_text'
    end

    def display_live_text
        @logger.info("Scanning #{@live_text_dir} for text files...")
        last_text_file = Dir.glob(File.join(@live_text_dir, '*')).last
        if last_text_file
          file_text = File.open(last_text_file).read
          @logger.info("last file: #{file_text}")
          file_text
        end
    end
    
end

if __FILE__ == $PROGRAM_NAME
    # Display Translation
    display = DisplayTranslation.new
    display.display_live_text
  end