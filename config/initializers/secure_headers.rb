SecureHeaders::Configuration.default do |config|
  config.hsts = SecureHeaders::OPT_OUT

  config.csp[:default_src] = []
  config.csp[:script_src] = ["'self'"]
  config.csp[:child_src] = ["'self'"]
  config.csp[:connect_src] = ["'self'"]
end
