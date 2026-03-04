Rack::Attack.cache.store = Rails.cache

# Allow health check endpoint without throttling
Rack::Attack.safelist("allow-health-check") do |request|
  request.path == "/up"
end

# Throttle login attempts to 5 per 20 seconds per IP
Rack::Attack.throttle("logins/ip", limit: 5, period: 20.seconds) do |request|
  request.ip if request.path == "/users/sign_in" && request.post?
end

# Throttle all requests to 300 per 5 minutes per IP
Rack::Attack.throttle("req/ip", limit: 300, period: 5.minutes) do |request|
  request.ip
end
