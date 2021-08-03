require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "sprockets/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Postal
  class Application < Rails::Application

    # Disable most generators
    config.generators do |g|
      g.orm             :active_record
      g.test_framework  false
      g.stylesheets     false
      g.javascripts     false
      g.helper          false
    end

    # Include from lib
    config.eager_load_namespaces << Postal

    # Disable field_with_errors
    config.action_view.field_error_proc = Proc.new { |t, _| t }

    # Load the tracking server middleware
    require "postal/tracking_middleware"
    config.middleware.use Postal::TrackingMiddleware

  end
end
