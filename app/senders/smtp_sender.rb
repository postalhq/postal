# frozen_string_literal: true

class SMTPSender < BaseSender

  attr_reader :endpoints

  # @param domain [String] the domain to send mesages to
  # @param source_ip_address [IPAddress] the IP address to send messages from
  # @param log_id [String] an ID to use when logging requests
  def initialize(domain, source_ip_address = nil, servers: nil, log_id: nil, rcpt_to: nil)
    super()
    @domain = domain
    @source_ip_address = source_ip_address
    @rcpt_to = rcpt_to

    # An array of servers to forcefully send the message to
    @servers = servers
    # Stores all connection errors which we have seen during this send sesssion.
    @connection_errors = []
    # Stores all endpoints that we have attempted to deliver mail to
    @endpoints = []
    # Generate a log ID which can be used if none has been provided to trace
    # this SMTP session.
    @log_id = log_id || SecureRandom.alphanumeric(8).upcase
  end

  def start
    servers = @servers || self.class.smtp_relays || resolve_mx_records_for_domain || []

    servers.each do |server|
      server.endpoints.each do |endpoint|
        result = connect_to_endpoint(endpoint)
        return endpoint if result
      end
    end

    false
  end

  def send_message(message)
    # If we don't have a current endpoint than we should raise an error.
    if @current_endpoint.nil?
      return create_result("SoftFail") do |r|
        r.retry = true
        r.details = "No SMTP servers were available for #{@domain}."
        if @endpoints.empty?
          r.details += " No hosts to try."
        else
          hostnames = @endpoints.map { |e| e.server.hostname }.uniq
          r.details += " Tried #{hostnames.to_sentence}."
        end
        r.output = @connection_errors.join(", ")
        r.connect_error = true
      end
    end

    mail_from = determine_mail_from_for_message(message)
    raw_message = message.raw_message

    # Append the Resent-Sender header to the mesage to include the
    # MAIL FROM if the installation is configured to use that?
    if Postal::Config.postal.use_resent_sender_header?
      raw_message = "Resent-Sender: #{mail_from}\r\n" + raw_message
    end

    rcpt_to = determine_rcpt_to_for_message(message)
    logger.info "Sending message #{message.server.id}::#{message.id} to #{rcpt_to}"
    send_message_to_smtp_client(raw_message, mail_from, rcpt_to)
  end

  def finish
    @endpoints.each(&:finish_smtp_session)
  end

  private

  # Take a message and attempt to send it to the SMTP server that we are
  # currently connected to. If there is a connection error, we will just
  # reset the client and retry again once.
  #
  # @param raw_message [String] the raw message to send
  # @param mail_from [String] the MAIL FROM address to use
  # @param rcpt_to [String] the RCPT TO address to use
  # @param retry_on_connection_error [Boolean] if true, we will retry the connection if there is an error
  #
  # @return [SendResult]
  def send_message_to_smtp_client(raw_message, mail_from, rcpt_to, retry_on_connection_error: true)
    start_time = Time.now
    smtp_result = @current_endpoint.send_message(raw_message, mail_from, [rcpt_to])
    logger.info "Accepted by #{@current_endpoint} for #{rcpt_to}"
    create_result("Sent", start_time) do |r|
      r.details = "Message for #{rcpt_to} accepted by #{@current_endpoint}"
      r.details += " (from #{@current_endpoint.smtp_client.source_address})" if @current_endpoint.smtp_client.source_address
      r.output = smtp_result.string
    end
  rescue Net::SMTPServerBusy, Net::SMTPAuthenticationError, Net::SMTPSyntaxError, Net::SMTPUnknownError, Net::ReadTimeout => e
    logger.error "#{e.class}: #{e.message}"
    @current_endpoint.reset_smtp_session

    create_result("SoftFail", start_time) do |r|
      r.details = "Temporary SMTP delivery error when sending to #{@current_endpoint}"
      r.output = e.message
      if e.message =~ /(\d+) seconds/
        r.retry = ::Regexp.last_match(1).to_i + 10
      elsif e.message =~ /(\d+) minutes/
        r.retry = (::Regexp.last_match(1).to_i * 60) + 10
      else
        r.retry = true
      end
    end
  rescue Net::SMTPFatalError => e
    logger.error "#{e.class}: #{e.message}"
    @current_endpoint.reset_smtp_session

    create_result("HardFail", start_time) do |r|
      r.details = "Permanent SMTP delivery error when sending to #{@current_endpoint}"
      r.output = e.message
    end
  rescue StandardError => e
    logger.error "#{e.class}: #{e.message}"
    @current_endpoint.reset_smtp_session

    if defined?(Sentry)
      # Sentry.capture_exception(e, extra: { log_id: @log_id, server_id: message.server.id, message_id: message.id })
    end

    create_result("SoftFail", start_time) do |r|
      r.type = "SoftFail"
      r.retry = true
      r.details = "An error occurred while sending the message to #{@current_endpoint}"
      r.output = e.message
    end
  end

  # Return the MAIL FROM which should be used for the given message
  #
  # @param message [MessageDB::Message]
  # @return [String]
  def determine_mail_from_for_message(message)
    return "" if message.bounce

    # If the domain has a valid custom return path configured, return
    # that.
    if message.domain.return_path_status == "OK"
      return "#{message.server.token}@#{message.domain.return_path_domain}"
    end

    "#{message.server.token}@#{Postal::Config.dns.return_path_domain}"
  end

  # Return the RCPT TO to use for the given message in this sending session
  #
  # @param message [MessageDB::Message]
  # @return [String]
  def determine_rcpt_to_for_message(message)
    return @rcpt_to if @rcpt_to

    message.rcpt_to
  end

  # Return an array of server hostnames which should receive this message
  #
  # @return [Array<String>]
  def resolve_mx_records_for_domain
    hostnames = DNSResolver.local.mx(@domain, raise_timeout_errors: true).map(&:last)
    return [SMTPClient::Server.new(@domain)] if hostnames.empty?

    hostnames.map { |hostname| SMTPClient::Server.new(hostname) }
  end

  # Attempt to begin an SMTP sesssion for the given endpoint. If successful, this endpoint
  # becomes the current endpoints for the SMTP sender.
  #
  # Returns true if the session was established.
  # Returns false if the session could not be established.
  #
  # @param endpoint [SMTPClient::Endpoint]
  # @return [Boolean]
  def connect_to_endpoint(endpoint, allow_ssl: true)
    if (@source_ip_address && @source_ip_address.ipv6.blank? && endpoint.ipv6?) || Postal::Config.smtp.disable_ipv6
      # Don't try to use IPv6 if the IP address we're sending from doesn't support it or if it's disabled in the config.
      return false
    end

    # Add this endpoint to the list of endpoints that we have attempted to connect to
    @endpoints << endpoint unless @endpoints.include?(endpoint)

    endpoint.start_smtp_session(allow_ssl: allow_ssl, source_ip_address: @source_ip_address)
    logger.info "Connected to #{endpoint}"
    @current_endpoint = endpoint

    true
  rescue StandardError => e
    # Disconnect the SMTP client if we get any errors to avoid leaving
    # a connection around.
    endpoint.finish_smtp_session

    # If we get an SSL error, we can retry a connection without
    # ssl.
    if e.is_a?(OpenSSL::SSL::SSLError) && endpoint.server.ssl_mode == "Auto"
      logger.error "SSL error (#{e.message}), retrying without SSL"
      return connect_to_endpoint(endpoint, allow_ssl: false)
    end

    # Otherwise, just log the connection error and return false
    logger.error "Cannot connect to #{endpoint} (#{e.class}: #{e.message})"
    @connection_errors << e.message unless @connection_errors.include?(e.message)

    false
  end

  # Create a new result object
  #
  # @param type [String] the type of result
  # @param start_time [Time] the time the operation started
  # @yieldparam [SendResult] the result object
  # @yieldreturn [void]
  #
  # @return [SendResult]
  def create_result(type, start_time = nil)
    result = SendResult.new
    result.type = type
    result.log_id = @log_id
    result.secure = @current_endpoint&.smtp_client&.secure_socket? ? true : false
    yield result if block_given?
    if start_time
      result.time = (Time.now - start_time).to_f.round(2)
    end
    result
  end

  def logger
    @logger ||= Postal.logger.create_tagged_logger(log_id: @log_id)
  end

  class << self

    # Return an array of SMTP relays as configured. Returns nil
    # if no SMTP relays are configured.
    #
    def smtp_relays
      return @smtp_relays if instance_variable_defined?("@smtp_relays")

      relays = Postal::Config.postal.smtp_relays
      return nil if relays.nil?

      relays = relays.filter_map do |relay|
        next unless relay.host.present?

        SMTPClient::Server.new(relay.host, port: relay.port, ssl_mode: relay.ssl_mode)
      end

      @smtp_relays = relays.empty? ? nil : relays
    end

  end

end
