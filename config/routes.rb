Rails.application.routes.draw do
  get "errors/not_found"
  get "errors/internal_error"
  get "hello/index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  get "hello", to: "hello#index"

  match "/404", to: "errors#not_found", via: :all
  match "/500", to: "errors#internal_error", via: :all

  namespace :api do
    # Routes for tracks
    resources :tracks, only: [ :index ]
    post "/tracks/rescan", to: "tracks#rescan"

    # Routes for DASH
    post "/prepare-dash", to: "dash#prepare_dash"
    get "/status/:id", to: "dash#status"

    get "/stream/:id", to: "dash#stream"
  end

  # Route for serving DASH files
  get "/dash/*path", to: proc { |env|
    # Extract the path after "/dash/"
    path = env["PATH_INFO"].sub("/dash/", "")
    # Serve the file from the DASH directory
    dash_path = Rails.root.join("public", "dash", path).to_s

    if File.exist?(dash_path)
      # Set the correct Content-Type based on extension
      content_type = case File.extname(dash_path).downcase
      when ".mpd"
                       "application/dash+xml"
      when ".m3u8"
                       "application/vnd.apple.mpegurl"
      when ".ts"
                       "video/mp2t"
      when ".m4s"
                       "video/iso.segment"
      else
                       "application/octet-stream"
      end

      [ 200, {
        "Content-Type" => content_type,
        "Access-Control-Allow-Origin" => "*"
      }, [ File.read(dash_path) ] ]
    else
      [ 404, { "Content-Type" => "text/plain" }, [ "Not Found" ] ]
    end
  }

  # Route for root (will serve index.html from the public directory)
  root to: proc { |env|
    [ 200, { "Content-Type" => "text/html" }, [ File.read(Rails.root.join("public", "index.html")) ] ]
  }
end
