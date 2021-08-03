module Postal
  class HTTPSender < Sender

    def initialize(endpoint, options = {})
      @endpoint = endpoint
      @options = options
      @log_id = Nifty::Utils::RandomString.generate(length: 8).upcase
    end

    def send_message(message)
      start_time = Time.now
      result = SendResult.new
      result.log_id = @log_id

      request_options = {}
      request_options[:sign] = true
      request_options[:timeout] = @endpoint.timeout || 5
      case @endpoint.encoding
      when "BodyAsJSON"
        request_options[:json] = parameters(message, flat: false).to_json
      when "FormData"
        request_options[:params] = parameters(message, flat: true)
      end

      log "Sending request to #{@endpoint.url}"
      response = Postal::HTTP.post(@endpoint.url, request_options)
      result.secure = !!response[:secure]
      result.details = "Received a #{response[:code]} from #{@endpoint.url}"
      log "  -> Received: #{response[:code]}"
      if response[:body]
        log "  -> Body: #{response[:body][0, 255]}"
        result.output = response[:body].to_s[0, 500].strip
      end
      if response[:code] >= 200 && response[:code] < 300
        #  This is considered a success
        result.type = "Sent"
      elsif response[:code] >= 500 && response[:code] < 600
        # This is temporary. They might fix their server so it should soft fail.
        result.type = "SoftFail"
        result.retry = true
      elsif response[:code] < 0
        # Connection/SSL etc... errors
        result.type = "SoftFail"
        result.retry = true
        result.connect_error = true
      elsif response[:code] == 429
        # Rate limit exceeded, treat as a hard fail and don't send bounces
        result.type = "HardFail"
        result.suppress_bounce = true
      else
        # This is permanent. Any other error isn't cool with us.
        result.type = "HardFail"
      end
      result.time = (Time.now - start_time).to_f.round(2)
      result
    end

    private

    def log(text)
      Postal.logger_for(:http_sender).info("[#{@log_id}] #{text}")
    end

    def parameters(message, options = {})
      case @endpoint.format
      when "Hash"
        hash = {
          id: message.id,
          rcpt_to: message.rcpt_to,
          mail_from: message.mail_from,
          token: message.token,
          subject: message.subject,
          message_id: message.message_id,
          timestamp: message.timestamp.to_f,
          size: message.size,
          spam_status: message.spam_status,
          bounce: message.bounce == 1 ? true : false,
          received_with_ssl: message.received_with_ssl == 1,
          to: message.headers["to"]&.last,
          cc: message.headers["cc"]&.last,
          from: message.headers["from"]&.last,
          date: message.headers["date"]&.last,
          in_reply_to: message.headers["in-reply-to"]&.last,
          references: message.headers["references"]&.last,
          html_body: message.html_body,
          attachment_quantity: message.attachments.size,
          auto_submitted: message.headers["auto-submitted"]&.last,
          reply_to: message.headers["reply-to"]
        }

        if @endpoint.strip_replies
          hash[:plain_body], hash[:replies_from_plain_body] = Postal::ReplySeparator.separate(message.plain_body)
        else
          hash[:plain_body] = message.plain_body
        end

        if @endpoint.include_attachments?
          if options[:flat]
            message.attachments.each_with_index do |a, i|
              hash["attachments[#{i}][filename]"] = a.filename
              hash["attachments[#{i}][content_type]"] = a.content_type
              hash["attachments[#{i}][size]"] = a.body.to_s.bytesize.to_s
              hash["attachments[#{i}][data]"] = Base64.encode64(a.body.to_s)
            end
          else
            hash[:attachments] = message.attachments.map do |a|
              {
                filename: a.filename,
                content_type: a.mime_type,
                size: a.body.to_s.bytesize,
                data: Base64.encode64(a.body.to_s)
              }
            end
          end
        end

        hash
      when "RawMessage"
        {
          id: message.id,
          rcpt_to: message.rcpt_to,
          mail_from: message.mail_from,
          message: Base64.encode64(message.raw_message),
          base64: true,
          size: message.size.to_i
        }
      else
        {}
      end
    end

  end
end
