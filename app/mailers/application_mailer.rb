class ApplicationMailer < ActionMailer::Base

  default from: "#{Postal.smtp_from_name} <#{Postal.smtp_from_address}>"
  layout false

end
