class PruneWebhookRequestsJob < Postal::Job

  def perform
    Server.all.each do |s|
      log "Pruning webhook requests for server #{s.id}"
      s.message_db.webhooks.prune
    end
  end

end
