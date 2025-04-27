class ErrorsController < ApplicationController
  def not_found
    render json: { error: 'Resource not found', status: 404 }, status: :not_found
  end

  def internal_error
    render json: { error: 'Internal server error', status: 500 }, status: :internal_server_error
  end
end
