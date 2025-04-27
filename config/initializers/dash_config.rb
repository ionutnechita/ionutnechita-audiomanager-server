# Configuration for DASH Audio Server

# Create a struct for configuration
DashConfig = Struct.new(
 :music_dir,
 :dash_dir,
 :allowed_exts,
 :max_workers,
 :ffmpeg_path,
 :mp4box_path,
 :audio_bitrates,
 :segment_duration
)

# Initialize the configuration
Rails.application.config.dash_config = DashConfig.new

# Set default values for configuration
config = Rails.application.config.dash_config

# Music directory
config.music_dir = ENV["MUSIC_DIR"] || Rails.root.join("music_library")

# Directory for DASH content
config.dash_dir = Rails.root.join("public", "dash")

# Allowed extensions for audio files
config.allowed_exts = [ ".mp3", ".flac", ".wav", ".ogg", ".m4a" ]

# Maximum number of workers for parallel processing
config.max_workers = ENV["MAX_WORKERS"] ? ENV["MAX_WORKERS"].to_i : Concurrent.processor_count

# Paths for ffmpeg and MP4Box
config.ffmpeg_path = "ffmpeg"
config.mp4box_path = "MP4Box"

# Audio bitrates for adaptation
config.audio_bitrates = [ "512k", "256k", "90k" ]

# Segment duration in seconds
config.segment_duration = 4

# Check that necessary executables are available
begin
 `#{config.ffmpeg_path} -version`
 Rails.logger.info "FFmpeg found: #{config.ffmpeg_path}"
rescue Errno::ENOENT
 Rails.logger.warn "Warning: FFmpeg was not found in PATH. Conversions will fail."
end

begin
 `#{config.mp4box_path} -version`
 Rails.logger.info "MP4Box found: #{config.mp4box_path}"
rescue Errno::ENOENT
 Rails.logger.warn "Warning: MP4Box was not found in PATH. Conversions will fail."
end

# Ensure necessary directories exist
FileUtils.mkdir_p(config.dash_dir) unless Dir.exist?(config.dash_dir)
FileUtils.mkdir_p(config.music_dir) unless Dir.exist?(config.music_dir)

Rails.logger.info "DASH Config: Music dir: #{config.music_dir}"
Rails.logger.info "DASH Config: DASH dir: #{config.dash_dir}"
