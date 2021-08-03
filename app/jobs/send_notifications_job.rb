class SendNotificationsJob < Postal::Job

  def perform
    Server.send_send_limit_notifications
  end

end
