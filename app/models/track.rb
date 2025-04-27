class Track < ApplicationRecord
  # Validations
  validates :title, presence: true
  validates :path, presence: true, uniqueness: true

  # Virtual attributes for DASH URL
  attr_accessor :dash_url

  # Generates a unique ID from the file path
  def self.create_id_from_path(path)
    # Replace non-alphanumeric characters with -
    File.basename(path).gsub(/[^a-zA-Z0-9]/, "-")
  end

  # Checks if the track has a DASH manifest available
  def dash_ready?
    dash_path = Rails.root.join(Rails.configuration.dash_config.dash_dir, slug, "manifest.mpd")
    File.exist?(dash_path)
  end

  # Returns the URL for the DASH manifest
  def dash_url
    return nil unless dash_ready?
    "/dash/#{slug}/manifest.mpd"
  end

  # Gets the conversion status for DASH
  def dash_status
    status = Rails.cache.read("dash_status:#{id}")
    return { status: "ready", url: dash_url } if dash_ready?
    return { status: "not_started" } if status.nil?
    status
  end

  # Sets the conversion status for DASH
  def set_dash_status(status_hash)
    Rails.cache.write("dash_status:#{id}", status_hash)
  end

  # Scans the music directory and loads all tracks
  def self.scan_music_directory
    config = Rails.configuration.dash_config
    music_dir = config.music_dir
    allowed_exts = config.allowed_exts

    tracks_count = 0
    Dir.glob("#{music_dir}/**/*").each do |path|
      next if File.directory?(path)

      ext = File.extname(path).downcase
      next unless allowed_exts.include?(ext)

      begin
        track_info = extract_track_info(path)
        next unless track_info

        Rails.logger.info("Processing track: #{track_info[:title]}")

        # Use find_or_create_by with block to set properties
        track = Track.find_or_create_by(path: track_info[:path]) do |t|
          t.title = track_info[:title]
          t.artist = track_info[:artist]
          t.album = track_info[:album]
          t.format = track_info[:format]
          t.slug = track_info[:slug]
        end

        if track.persisted?
          tracks_count += 1
        else
          Rails.logger.error("Could not save track: #{track.errors.full_messages.join(', ')}")
        end
      rescue => e
        Rails.logger.error("Error processing file #{path}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
      end
    end

    tracks_count
  end

  private

  # Extracts metadata from the audio file using ffprobe
  def self.extract_track_info(file_path)
    slug = create_id_from_path(file_path)
    file_name = File.basename(file_path)

    # Check if a DASH URL already exists for this track
    dash_url = nil
    dash_path = Rails.root.join(Rails.configuration.dash_config.dash_dir, slug, "manifest.mpd")
    dash_url = "/dash/#{slug}/manifest.mpd" if File.exist?(dash_path)

    # Use ffprobe to extract metadata
    # Escape the file path for shell
    escaped_path = file_path.shellescape

    cmd = [
      Rails.configuration.dash_config.ffmpeg_path,
      "-v", "quiet",
      "-print_format", "json",
      "-show_format",
      escaped_path
    ]

    begin
      output = `#{cmd.join(" ")}`
      result = JSON.parse(output)

      tags = result["format"]["tags"] || {}
      title = tags["title"].presence || File.basename(file_path, ".*")
      artist = tags["artist"].presence || "Unknown"
      album = tags["album"].presence || "Unknown"

      {
        title: title,
        artist: artist,
        album: album,
        format: File.extname(file_path).delete(".").downcase,
        path: file_path,
        slug: slug,
        dash_url: dash_url
      }
    rescue => e
      # If ffprobe fails, use the filename for basic information
      {
        title: File.basename(file_path, ".*"),
        artist: "Unknown",
        album: "Unknown",
        format: File.extname(file_path).delete(".").downcase,
        path: file_path,
        slug: slug,
        dash_url: dash_url
      }
    end
  end
end
