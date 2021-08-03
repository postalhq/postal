class RequeueWebhooksJob < Postal::Job

  def perform
    WebhookRequest.requeue_all
  end

end
