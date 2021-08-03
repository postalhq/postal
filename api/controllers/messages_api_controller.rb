controller :messages do
  friendly_name "Messages API"
  description "This API allows you to access message details"
  authenticator :server

  action :message do
    title "Return message details"
    description "Returns all details about a message"
    param :id, "The ID of the message", type: Integer, required: true
    returns Hash, structure: :message, structure_opts: { paramable: { expansions: false } }
    error "MessageNotFound", "No message found matching provided ID", attributes: { id: "The ID of the message" }
    action do
      begin
        message = identity.server.message(params.id)
      rescue Postal::MessageDB::Message::NotFound => e
        error "MessageNotFound", id: params.id
      end
      structure :message, message, return: true
    end
  end

  action :deliveries do
    title "Return deliveries for a message"
    description "Returns an array of deliveries which have been attempted for this message"
    param :id, "The ID of the message", type: Integer, required: true
    returns Array, structure: :delivery, structure_opts: { full: true }
    error "MessageNotFound", "No message found matching provided ID", attributes: { id: "The ID of the message" }
    action do
      begin
        message = identity.server.message(params.id)
      rescue Postal::MessageDB::Message::NotFound => e
        error "MessageNotFound", id: params.id
      end
      message.deliveries.map do |d|
        structure :delivery, d
      end
    end
  end
end
