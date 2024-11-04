# frozen_string_literal: true

config = Postal::Config.oidc
if config.enabled?
  client_options = { identifier: config.identifier, secret: config.secret }

  client_options[:redirect_uri] = "#{Postal::Config.postal.web_protocol}://#{Postal::Config.postal.web_hostname}/auth/oidc/callback"

  unless config.discovery?
    client_options[:authorization_endpoint] = config.authorization_endpoint
    client_options[:token_endpoint] = config.token_endpoint
    client_options[:userinfo_endpoint] = config.userinfo_endpoint
    client_options[:jwks_uri] = config.jwks_uri
  end

  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :openid_connect, name: :oidc,
                              scope: config.scopes.map(&:to_sym),
                              uid_field: config.uid_field,
                              issuer: config.issuer,
                              pkce: config.pkce?,
                              discovery: config.discovery?,
                              client_options: client_options
  end

  OmniAuth.config.on_failure = proc do |env|
    SessionsController.action(:oauth_failure).call(env)
  end
end
