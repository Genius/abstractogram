class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  http_basic_authenticate_with :name => ENV["BASICAUTH_NAME"].to_s, :password => ENV["BASICAUTH_PASSWORD"].to_s
end
