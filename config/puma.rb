require_relative "../lib/postal/config"
threads_count = Postal.config.web_server&.max_threads&.to_i || 5
threads         threads_count, threads_count
bind_address  = Postal.config.web_server&.bind_address || "127.0.0.1"
bind_port     = ENV["PORT"] || Postal.config.web_server&.port&.to_i || 5000
bind            "tcp://#{bind_address}:#{bind_port}"
environment     Postal.config.rails&.environment || "development"
prune_bundler
quiet false

if ENV["APP_ROOT"]
  directory ENV["APP_ROOT"]
end
