require './live_transcriber'
stream = "https://rtvelivesrc2.rtve.es/live-origin/24h-hls/bitrate_3.m3u8"
lt = LiveTranscriber.new stream
lt.start