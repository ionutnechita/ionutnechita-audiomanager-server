module Api
  class TracksController < ApplicationController
    # GET /api/tracks
    # Returns the list of tracks
    def index
      @tracks = Track.all
      render json: @tracks.map { |track| track_to_json(track) }
    end

    # POST /api/tracks/rescan
    # Rescans the music directory
    def rescan
      Thread.new do
        count = Track.scan_music_directory
        Rails.logger.info "Found #{count} tracks after rescanning"
      end

      render json: {
        status: "success",
        message: "Rescanning has begun"
      }
    end

    private

    # Converts a track to JSON format
    def track_to_json(track)
      {
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        format: track.format,
        dash_url: track.dash_url
      }
    end
  end
end
