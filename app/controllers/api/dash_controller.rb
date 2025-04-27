module Api
  class DashController < ApplicationController
    # POST /api/prepare-dash
    # Prepares a track for DASH streaming
    def prepare_dash
      track_id = dash_params[:track_id]

      unless track_id
        return render json: { error: "Track ID is required" }, status: :bad_request
      end

      track = Track.find_by(id: track_id)
      unless track
        return render json: { error: "Track not found" }, status: :not_found
      end

      # Check if the track is already being processed
      status = track.dash_status
      if status[:status] == "processing"
        return render json: {
          status: "processing",
          message: "Track is already being processed"
        }
      end

      # Set status as "processing"
      track.set_dash_status(status: "processing")

      # Add conversion job to queue
      DashConversionJob.perform_later(track.id)

      render json: {
        status: "processing",
        message: "Processing has started"
      }
    end

    # GET /api/status/:id
    # Returns the DASH processing status for a track
    def status
      track = Track.find_by(id: params[:id])

      unless track
        return render json: { error: "Track not found" }, status: :not_found
      end

      render json: track.dash_status
    end

    def stream
      track = Track.find_by(id: params[:id])

      unless track
        return render json: { error: "Track not found" }, status: :not_found
      end

      unless track.dash_ready?
        return render json: { error: "Track is not ready for streaming" }, status: :bad_request
      end

      # Redirect directly to the DASH manifest
      redirect_to "/dash/#{track.slug}/manifest.mpd"
    end

    private

    def dash_params
      params.require(:track).permit(:track_id)
    end
  end
end
