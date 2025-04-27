class ApplicationController < ActionController::API
  before_action :set_cors_headers

  private

  def set_cors_headers
    headers["Access-Control-Allow-Origin"] = "*"
    headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"

    if request.method == "OPTIONS"
      render status: :ok, json: {}
    end
  end
end
