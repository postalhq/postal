controller :send do
  friendly_name "Send API"
  description "This API allows you to send messages"
  authenticator :server

  action :message do
    title "Send a message"
    description "This action allows you to send a message by providing the appropriate options"
    # Acceptable Parameters
    param :to, "The e-mail addresses of the recipients (max 50)", type: Array
    param :cc, "The e-mail addresses of any CC contacts (max 50)", type: Array
    param :bcc, "The e-mail addresses of any BCC contacts (max 50)", type: Array
    param :from, "The e-mail address for the From header", type: String
    param :sender, "The e-mail address for the Sender header", type: String
    param :subject, "The subject of the e-mail", type: String
    param :tag, "The tag of the e-mail", type: String
    param :reply_to, "Set the reply-to address for the mail", type: String
    param :plain_body, "The plain text body of the e-mail", type: String
    param :html_body, "The HTML body of the e-mail", type: String
    param :attachments, "An array of attachments for this e-mail", type: Array
    param :headers, "A hash of additional headers", type: Hash
    param :bounce, "Is this message a bounce?", type: :boolean
    # Errors
    error "ValidationError", "The provided data was not sufficient to send an email", attributes: { errors: "A hash of error details" }
    error "NoRecipients", "There are no recipients defined to receive this message"
    error "NoContent", "There is no content defined for this e-mail"
    error "TooManyToAddresses", "The maximum number of To addresses has been reached (maximum 50)"
    error "TooManyCCAddresses", "The maximum number of CC addresses has been reached (maximum 50)"
    error "TooManyBCCAddresses", "The maximum number of BCC addresses has been reached (maximum 50)"
    error "FromAddressMissing", "The From address is missing and is required"
    error "UnauthenticatedFromAddress", "The From address is not authorised to send mail from this server"
    error "AttachmentMissingName", "An attachment is missing a name"
    error "AttachmentMissingData", "An attachment is missing data"
    # Return
    returns Hash
    # Action
    action do
      attributes = {}
      attributes[:to] = params.to
      attributes[:cc] = params.cc
      attributes[:bcc] = params.bcc
      attributes[:from] = params.from
      attributes[:sender] = params.sender
      attributes[:subject] = params.subject
      attributes[:reply_to] = params.reply_to
      attributes[:plain_body] = params.plain_body
      attributes[:html_body] = params.html_body
      attributes[:bounce] = params.bounce ? true : false
      attributes[:tag] = params.tag
      attributes[:custom_headers] = params.headers
      attributes[:attachments] = []
      (params.attachments || []).each do |attachment|
        next unless attachment.is_a?(Hash)

        attributes[:attachments] << { name: attachment["name"], content_type: attachment["content_type"], data: attachment["data"], base64: true }
      end
      message = OutgoingMessagePrototype.new(identity.server, request.ip, "api", attributes)
      message.credential = identity
      if message.valid?
        result = message.create_messages
        { message_id: message.message_id, messages: result }
      else
        error message.errors.first
      end
    end
  end

  action :raw do
    title "Send a raw RFC2882 message"
    description "This action allows you to send us a raw RFC2822 formatted message along with the recipients that it should be sent to. This is similar to sending a message through our SMTP service."
    param :mail_from, "The address that should be logged as sending the message", type: String, required: true
    param :rcpt_to, "The addresses this message should be sent to", type: Array, required: true
    param :data, "A base64 encoded RFC2822 message to send", type: String, required: true
    param :bounce, "Is this message a bounce?", type: :boolean
    returns Hash
    error "UnauthenticatedFromAddress", "The From address is not authorised to send mail from this server"
    action do
      # Decode the raw message
      raw_message = Base64.decode64(params.data)

      # Parse through mail to get the from/sender headers
      mail = Mail.new(raw_message.split("\r\n\r\n", 2).first)
      from_headers = { "from" => mail.from, "sender" => mail.sender }
      authenticated_domain = identity.server.find_authenticated_domain_from_headers(from_headers)

      # If we're not authenticated, don't continue
      if authenticated_domain.nil?
        error "UnauthenticatedFromAddress"
      end

      # Store the result ready to return
      result = { message_id: nil, messages: {} }
      params.rcpt_to.uniq.each do |rcpt_to|
        message = identity.server.message_db.new_message
        message.rcpt_to = rcpt_to
        message.mail_from = params.mail_from
        message.raw_message = raw_message
        message.received_with_ssl = true
        message.scope = "outgoing"
        message.domain_id = authenticated_domain.id
        message.credential_id = identity.id
        message.bounce = params.bounce ? 1 : 0
        message.save
        result[:message_id] = message.message_id if result[:message_id].nil?
        result[:messages][rcpt_to] = { id: message.id, token: message.token }
      end
      result
    end
  end
end
