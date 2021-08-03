require "postal/config"
if Postal.config&.smtp
  ActionMailer::Base.delivery_method = :smtp
  ActionMailer::Base.smtp_settings = { address: Postal.config.smtp.host, user_name: Postal.config.smtp.username, password: Postal.config.smtp.password, port: Postal.config.smtp.port || 25 }
end
