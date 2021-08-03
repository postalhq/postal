module Postal
  class BounceMessage

    def initialize(server, message)
      @server = server
      @message = message
    end

    def raw_message
      mail = Mail.new
      mail.to = @message.mail_from
      mail.from = "Mail Delivery Service <#{@message.route.description}>"
      mail.subject = "Mail Delivery Failed (#{@message.subject})"
      mail.text_part = body
      mail.attachments["Original Message.eml"] = { mime_type: "message/rfc822", encoding: "quoted-printable", content: @message.raw_message }
      mail.message_id = "<#{SecureRandom.uuid}@#{Postal.config.dns.return_path}>"
      mail.to_s
    end

    def queue
      message = @server.message_db.new_message
      message.scope = "outgoing"
      message.rcpt_to = @message.mail_from
      message.mail_from = @message.route.description
      message.domain_id = @message.domain&.id
      message.raw_message = raw_message
      message.bounce = 1
      message.bounce_for_id = @message.id
      message.save
      message.id
    end

    def postmaster_address
      @server.postmaster_address || "postmaster@#{@message.domain&.name || Postal.config.web.host}"
    end

    private

    def body
      <<-BODY.strip_heredoc
        This is the mail delivery service responsible for delivering mail to #{@message.route.description}.

        The message you've sent cannot be delivered. Your original message is attached to this message.

        For further assistance please contact #{postmaster_address}. Please include the details below to help us identify the issue.

        Message Token: #{@message.token}@#{@server.token}
        Orginal Message ID: #{@message.message_id}
        Mail from: #{@message.mail_from}
        Rcpt To: #{@message.rcpt_to}
      BODY
    end

  end
end
