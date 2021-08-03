class AppMailer < ApplicationMailer

  def verify_email_address(user)
    @user = user
    mail to: @user.email_address, subject: "Verify your new e-mail address"
  end

  def new_user(user)
    @user = user
    mail to: @user.email_address, subject: "Welcome to Postal"
  end

  def user_invite(user_invite, organization)
    @user_invite = user_invite
    @organization = organization
    mail to: @user_invite.email_address, subject: "Access the #{organization.name} organization on Postal"
  end

  def verify_domain(domain, email_address, user)
    @domain = domain
    @email_address = email_address
    @user = user
    mail to: email_address, subject: "Verify your ownership of #{@domain.name}"
  end

  def password_reset(user, return_to = nil)
    @user = user
    @return_to = return_to
    mail to: @user.email_address, subject: "Reset your Postal password"
  end

  def server_send_limit_approaching(server)
    @server = server
    mail to: @server.organization.notification_addresses, subject: "[#{server.full_permalink}] Mail server is approaching its send limit"
  end

  def server_send_limit_exceeded(server)
    @server = server
    mail to: @server.organization.notification_addresses, subject: "[#{server.full_permalink}] Mail server has exceeded its send limit"
  end

  def server_suspended(server)
    @server = server
    mail to: @server.organization.notification_addresses, subject: "[#{server.full_permalink}] Your mail server has been suspended"
  end

  def test_message(recipient)
    mail to: recipient, subject: "Postal SMTP Test Message"
  end

end
