class DashConversionJob < ApplicationJob
  queue_as :dash_conversion

  # Instead of an array, use a constant option or a specific method for delay
  retry_on StandardError, attempts: 3, wait: 5.seconds

  def perform(track_id)
    Rails.logger.info("DashConversionJob: Starting processing for track_id=#{track_id}")

    # Find the track
    track = Track.find_by(id: track_id)

    unless track
      Rails.logger.error("DashConversionJob: Track with id=#{track_id} not found")
      return
    end

    Rails.logger.info("DashConversionJob: Processing track '#{track.title}'")

    # Initialize the conversion service and execute the conversion
    service = DashConverterService.new(track)

    if service.convert_to_dash
      Rails.logger.info("DashConversionJob: Conversion completed successfully for '#{track.title}'")
    else
      Rails.logger.error("DashConversionJob: Conversion failed for '#{track.title}'")
      raise "DASH conversion failed for track_id=#{track_id}"
    end
  end
end
