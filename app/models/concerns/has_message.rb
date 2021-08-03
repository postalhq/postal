module HasMessage

  def self.included(base)
    base.extend ClassMethods
  end

  def message
    @message ||= server.message_db.message(message_id)
  end

  def message=(message)
    @message = message
    self.message_id = message&.id
  end

  module ClassMethods

    def include_message
      queued_messages = all.to_a
      server_ids = queued_messages.map(&:server_id).uniq
      if server_ids.size == 0
        return []
      elsif server_ids.size > 1
        raise Postal::Error, "'include_message' can only be used on collections of messages from the same server"
      end

      message_ids = queued_messages.map(&:message_id).uniq
      server = queued_messages.first&.server
      messages = server.message_db.messages(where: { id: message_ids }).each_with_object({}) do |message, hash|
        hash[message.id] = message
      end
      queued_messages.each do |queued_message|
        if m = messages[queued_message.message_id]
          queued_message.message = m
        end
      end
    end

  end

end
