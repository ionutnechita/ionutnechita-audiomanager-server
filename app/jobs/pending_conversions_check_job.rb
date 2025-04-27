class PendingConversionsCheckJob < ApplicationJob
  queue_as :default

  def perform
    # Find tracks that have been in "processing" state for too long
    # (for example, more than 30 minutes)
    processing_too_long = Track.where(status: "processing")
                               .where("updated_at < ?", 30.minutes.ago)

    processing_too_long.each do |track|
      Rails.logger.info "Found stuck conversion for track: #{track.id} - #{track.title}"

      # Reset status or retry conversion
      track.set_dash_status(status: "error", error: "Conversion timed out")

      # Optionally, re-queue the conversion
      DashConversionJob.perform_later(track.id)
    end

    Rails.logger.info "Checked #{processing_too_long.count} pending conversions"
  end
end
