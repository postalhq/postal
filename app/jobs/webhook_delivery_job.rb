class WebhookDeliveryJob < Postal::Job

  def perform
    if webhook_request = WebhookRequest.find_by_id(params["id"])
      if webhook_request.deliver
        log "Succesfully delivered"
      else
        log "Delivery failed"
      end
    else
      log "No webhook request found with ID '#{params['id']}'"
    end
  end

end
