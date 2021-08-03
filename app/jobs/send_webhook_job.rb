class SendWebhookJob < Postal::Job

  def perform
    if server = Server.find(params["server_id"])
      new_items = {}
      if params["payload"]
        for key, value in params["payload"]
          if key.to_s =~ /\A_(\w+)/
            begin
              new_items[$1] = server.message_db.message(value.to_i).webhook_hash
            rescue Postal::MessageDB::Message::NotFound
            end
          end
        end
      end

      new_items.each do |key, value|
        params["payload"].delete("_#{key}")
        params["payload"][key] = value
      end

      WebhookRequest.trigger(server, params["event"], params["payload"])
    else
      log "Couldn't find server with ID #{params['server_id']}"
    end
  end

end
