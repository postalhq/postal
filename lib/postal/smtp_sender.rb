require "resolv"

module Postal
  class SMTPSender < Sender

    def initialize(domain, source_ip_address, options = {})
      @domain = domain
      @source_ip_address = source_ip_address
      @options = options
      @smtp_client = nil
      @connection_errors = []
      @hostnames = []
      @log_id = Nifty::Utils::RandomString.generate(length: 8).upcase
    end

    def start
      servers.each do |server|
        if server.is_a?(SMTPEndpoint)
          hostname = server.hostname
          port = server.port || 25
          ssl_mode = server.ssl_mode
        elsif server.is_a?(Hash)
          hostname = server[:hostname]
          port = server[:port] || 25
          ssl_mode = server[:ssl_mode] || "Auto"
        else
          hostname = server
          port = 25
          ssl_mode = "Auto"
        end

        @hostnames << hostname
        [:aaaa, :a].each do |ip_type|
          if @source_ip_address && @source_ip_address.ipv6.blank? && ip_type == :aaaa
            # Don't try to use IPv6 if the IP address we're sending from doesn't support it.
            next
          end

          begin
            @remote_ip = lookup_ip_address(ip_type, hostname)
            if @remote_ip.nil?
              if ip_type == :a
                # As we can't resolve the last IP, we'll put this
                @connection_errors << "Could not resolve #{hostname}"
              end
              next
            end
            smtp_client = Net::SMTP.new(hostname, port)
            smtp_client.open_timeout = Postal.config.smtp_client.open_timeout
            smtp_client.read_timeout = Postal.config.smtp_client.read_timeout
            if @source_ip_address
              # Set the source IP as appropriate
              smtp_client.source_address = ip_type == :aaaa ? @source_ip_address.ipv6 : @source_ip_address.ipv4
            end
            case ssl_mode
            when "Auto"
              smtp_client.enable_starttls_auto(self.class.ssl_context_without_verify)
            when "STARTTLS"
              smtp_client.enable_starttls(self.class.ssl_context_with_verify)
            when "TLS"
              smtp_client.enable_tls(self.class.ssl_context_with_verify)
            else
              # Nothing
            end
            smtp_client.start(@source_ip_address ? @source_ip_address.hostname : self.class.default_helo_hostname)
            log "Connected to #{@remote_ip}:#{port} (#{hostname})"
          rescue => e
            log "Cannot connect to #{@remote_ip}:#{port} (#{hostname}) (#{e.class}: #{e.message})"
            @connection_errors << e.message unless @connection_errors.include?(e.message)
            smtp_client.disconnect rescue nil
            smtp_client = nil
          end

          if smtp_client
            @smtp_client = smtp_client
            return true
          end
        end
      end

      @connection_errors
    end

    def reconnect
      log "Reconnecting"
      @smtp_client&.finish rescue nil
      start
    end

    def safe_rset
      # Something went wrong sending the last email. Reset the connection if possible, else disconnect.
      begin
        @smtp_client.rset
      rescue
        # Don't reconnect, this would be rather rude if we don't have any more emails to send.
        @smtp_client.finish rescue nil
      end
    end

    def send_message(message, force_rcpt_to = nil)
      start_time = Time.now
      result = SendResult.new
      result.log_id = @log_id
      if @smtp_client && !@smtp_client.started?
        # For some reason we had an SMTP connection but it's no longer connected.
        # Make a new one.
        start
      end

      if @smtp_client
        result.secure = @smtp_client.secure_socket?
      end

      begin
        if message.bounce == 1
          mail_from = ""
        elsif message.domain.return_path_status == "OK"
          mail_from = "#{message.server.token}@#{message.domain.return_path_domain}"
        else
          mail_from = "#{message.server.token}@#{Postal.config.dns.return_path}"
        end
        raw_message = "Resent-Sender: #{mail_from}\r\n" + message.raw_message
        tries = 0
        begin
          if @smtp_client.nil?
            log "-> No SMTP server available for #{@domain}"
            log "-> Hostnames: #{@hostnames.inspect}"
            log "-> Errors: #{@connection_errors.inspect}"
            result.type = "SoftFail"
            result.retry = true
            result.details = "No SMTP servers were available for #{@domain}. Tried #{@hostnames.to_sentence}"
            result.output = @connection_errors.join(", ")
            result.connect_error = true
            return result
          else
            @smtp_client.rset_errors
            rcpt_to = force_rcpt_to || @options[:force_rcpt_to] || message.rcpt_to
            log "Sending message #{message.server.id}::#{message.id} to #{rcpt_to}"
            smtp_result = @smtp_client.send_message(raw_message, mail_from, [rcpt_to])
          end
        rescue Errno::ECONNRESET, Errno::EPIPE, OpenSSL::SSL::SSLError
          if (tries += 1) < 2
            reconnect
            retry
          else
            raise
          end
        end
        result.type = "Sent"
        result.details = "Message for #{rcpt_to} accepted by #{destination_host_description}"
        if @smtp_client.source_address
          result.details += " (from #{@smtp_client.source_address})"
        end
        result.output = smtp_result.string
        log "Message sent ##{message.id} to #{destination_host_description} for #{rcpt_to}"
      rescue Net::SMTPServerBusy, Net::SMTPAuthenticationError, Net::SMTPSyntaxError, Net::SMTPUnknownError, Net::ReadTimeout => e
        log "#{e.class}: #{e.message}"
        result.type = "SoftFail"
        result.retry = true
        result.details = "Temporary SMTP delivery error when sending to #{destination_host_description}"
        result.output = e.message
        if e.to_s =~ /(\d+) seconds/
          result.retry = $1.to_i + 10
        elsif e.to_s =~ /(\d+) minutes/
          result.retry = ($1.to_i * 60) + 10
        end

        safe_rset
      rescue Net::SMTPFatalError => e
        log "#{e.class}: #{e.message}"
        result.type = "HardFail"
        result.details = "Permanent SMTP delivery error when sending to #{destination_host_description}"
        result.output = e.message
        safe_rset
      rescue => e
        log "#{e.class}: #{e.message}"
        if defined?(Raven)
          Raven.capture_exception(e, extra: { log_id: @log_id, server_id: message.server.id, message_id: message.id })
        end
        result.type = "SoftFail"
        result.retry = true
        result.details = "An error occurred while sending the message to #{destination_host_description}"
        result.output = e.message
        safe_rset
      end

      result.time = (Time.now - start_time).to_f.round(2)
      return result
    ensure
    end

    def finish
      log "Finishing up"
      @smtp_client&.finish
    end

    private

    def servers
      @options[:servers] || self.class.relay_hosts || @servers ||= begin
        mx_servers = MXLookup.lookup(@domain)
        if mx_servers.empty?
          mx_servers = [@domain] # This will be resolved to an A or AAAA record later
        end
        mx_servers
      end
    end

    def log(text)
      Postal.logger_for(:smtp_sender).info "[#{@log_id}] #{text}"
    end

    def destination_host_description
      "#{@hostnames.last} (#{@remote_ip})"
    end

    def lookup_ip_address(type, hostname)
      records = []
      Resolv::DNS.open do |dns|
        dns.timeouts = [10, 5]
        case type
        when :a
          records = dns.getresources(hostname, Resolv::DNS::Resource::IN::A)
        when :aaaa
          records = dns.getresources(hostname, Resolv::DNS::Resource::IN::AAAA)
        end
      end
      records.first&.address&.to_s&.downcase
    end


    class << self

      def ssl_context_with_verify
        @ssl_context_with_verify ||= begin
          c = OpenSSL::SSL::SSLContext.new
          c.verify_mode = OpenSSL::SSL::VERIFY_PEER
          c.cert_store = OpenSSL::X509::Store.new
          c.cert_store.set_default_paths
          c
        end
      end

      def ssl_context_without_verify
        @ssl_context_without_verify ||= begin
          c = OpenSSL::SSL::SSLContext.new
          c.verify_mode = OpenSSL::SSL::VERIFY_NONE
          c
        end
      end

      def default_helo_hostname
        Postal.config.dns.helo_hostname || Postal.config.dns.smtp_server_hostname || "localhost"
      end

      def relay_hosts
        hosts = Postal.config.smtp_relays.map do |relay|
          if relay.hostname.present?
            {
              hostname: relay.hostname,
              port: relay.port,
              ssl_mode: relay.ssl_mode
            }
          else
            nil
          end
        end.compact
        hosts.empty? ? nil : hosts
      end

    end

  end
end
