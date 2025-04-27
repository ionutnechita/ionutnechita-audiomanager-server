class DashConverterService
  attr_reader :track, :output_dir, :manifest_path, :config

  def initialize(track)
    @track = track
    @config = Rails.configuration.dash_config
    @output_dir = Rails.root.join(@config.dash_dir, track.slug)
    @manifest_path = File.join(@output_dir, "manifest.mpd")
  end

  def convert_to_dash
    track.set_dash_status(status: "processing")

    FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

    require "open3"

    cmd = [
      config.ffmpeg_path,
      "-y",                                    # Overwrite existing files
      "-i", track.path,                        # Input file
      "-map", "0:a",                           # Select only audio stream
      "-c:a", "libopus",
      "-b:a", "80k",                          # Reasonable bitrate
      "-vn",                                   # Exclude video streams (including album cover)
      "-f", "dash",                            # DASH format
      "-dash_segment_type", "mp4",             # Explicit segment type
      "-single_file", "1",                     # Generate a single file for representations
      "-single_file_name", "stream.m4s",       # Single file name
      "-init_seg_name", "init.mp4",            # Standard name for init segment
      "-media_seg_name", "chunk-$Number$.m4s", # Standard name for media segments
      "-seg_duration", "4",                    # Larger segments for fewer interruptions
      "-use_template", "1",                    # Use templates
      "-use_timeline", "0",                    # Don't use timeline (simplifies format)
      "-window_size", "0",                     # Set window size to 0 (all segments)
      manifest_path                            # Path for manifest
    ]

    Rails.logger.info("Generating DASH manifest for track #{track.title}")
    Rails.logger.info("Using command: #{cmd.join(' ')}")

    begin
      stdout, stderr, status = Open3.capture3(*cmd)

      unless status.success?
        Rails.logger.error("Error creating DASH manifest: #{stderr}")
        track.set_dash_status(status: "error", error: "Error creating DASH manifest: #{stderr}")
        return false
      end

      fix_manifest_for_compatibility

      track.set_dash_status(status: "ready", url: "/dash/#{track.slug}/manifest.mpd")
      Rails.logger.info("Track #{track.title} has been successfully converted to VLC-compatible DASH format")

      true
    rescue => e
      Rails.logger.error("Error processing DASH: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      track.set_dash_status(status: "error", error: e.message)
      false
    end
  end

  def fix_manifest_for_compatibility
    return unless File.exist?(manifest_path)

    begin
      content = File.read(manifest_path)

      unless content.include?('minBufferTime="PT')
        content.sub!('<MPD xmlns="urn:mpeg:dash:schema:mpd:2011"',
                    '<MPD xmlns="urn:mpeg:dash:schema:mpd:2011" minBufferTime="PT4S" profiles="urn:mpeg:dash:profile:isoff-on-demand:2011"')
      end

      unless content.include?('mimeType="audio/mp4"')
        content.gsub!("<AdaptationSet",
                     '<AdaptationSet mimeType="audio/mp4" contentType="audio" subsegmentAlignment="true"')
      end

      unless content.include?('codecs="opus"')
        content.gsub!("<Representation",
                     '<Representation codecs="opus"')
      end

      content.gsub!(/<SegmentTemplate.*?>(.*?)<\/SegmentTemplate>/m) do |match|
        '<SegmentTemplate initialization="init.mp4" media="chunk-$Number$.m4s" startNumber="1" timescale="1000" duration="4000"/>'
      end

      File.write(manifest_path, content)
    rescue => e
      Rails.logger.error("Error in fix_manifest_for_compatibility: #{e.message}")
    end
  end
end
