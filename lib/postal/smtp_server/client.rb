require "resolv"
require "nifty/utils/random_string"

module Postal
  module SMTPServer
    class Client

      CRAM_MD5_DIGEST = OpenSSL::Digest.new("md5")
      LOG_REDACTION_STRING = "[redacted]".freeze

      attr_reader :logging_enabled

      def initialize(ip_address)
        @logging_enabled = true
        @ip_address = ip_address
        if @ip_address
          check_ip_address
          @state = :welcome
        else
          @state = :preauth
        end
        transaction_reset
      end

      def check_ip_address
        if @ip_address && Postal.config.smtp_server.log_exclude_ips && @ip_address =~ Regexp.new(Postal.config.smtp_server.log_exclude_ips)
          @logging_enabled = false
        end
      end

      def transaction_reset
        @recipients = []
        @mail_from = nil
        @data = nil
        @headers = nil
      end

      def id
        @id ||= Nifty::Utils::RandomString.generate(length: 6).upcase
      end

      def handle(data)
        if @state == :preauth
          return proxy(data)
        end

        log "\e[32m<= #{sanitize_input_for_log(data.strip)}\e[0m"
        if @proc
          @proc.call(data)

        else
          handle_command(data)
        end
      end

      def sanitize_input_for_log(data)
        if @password_expected_next
          @password_expected_next = false
          if data =~ /\A[a-z0-9]{3,}=*\z/i
            return LOG_REDACTION_STRING
          end
        end

        data = data.dup
        data.gsub!(/(.*AUTH \w+) (.*)\z/i) { "#{$1} #{LOG_REDACTION_STRING}" }
        data
      end

      def finished?
        @finished || false
      end

      def start_tls?
        @start_tls || false
      end

      def start_tls=(value)
        @start_tls = value
      end

      def handle_command(data)
        case data
        when /^QUIT/i           then quit
        when /^STARTTLS/i       then starttls
        when /^EHLO/i           then ehlo(data)
        when /^HELO/i           then helo(data)
        when /^RSET/i           then rset
        when /^NOOP/i           then noop
        when /^AUTH PLAIN/i     then auth_plain(data)
        when /^AUTH LOGIN/i     then auth_login(data)
        when /^AUTH CRAM-MD5/i  then auth_cram_md5(data)
        when /^MAIL FROM/i      then mail_from(data)
        when /^RCPT TO/i        then rcpt_to(data)
        when /^DATA/i           then data(data)
        else
          "502 Invalid/unsupported command"
        end
      end

      def log(text)
        return false unless @logging_enabled

        Postal.logger_for(:smtp_server).debug "[#{id}] #{text}"
      end

      private

      def resolve_hostname
        @hostname = Resolv.new.getname(@ip_address) rescue @ip_address
      end

      def proxy(data)
        if m = data.match(/\APROXY (.+) (.+) (.+) (.+) (.+)\z/)
          @ip_address = m[2]
          check_ip_address
          @state = :welcome
          log "\e[35m   Client identified as #{@ip_address}\e[0m"
          "220 #{Postal.config.dns.smtp_server_hostname} ESMTP Postal/#{id}"
        else
          @finished = true
          "502 Proxy Error"
        end
      end

      def quit
        @finished = true
        "221 Closing Connection"
      end

      def starttls
        if Postal.config.smtp_server.tls_enabled?
          @start_tls = true
          @tls = true
          "220 Ready to start TLS"
        else
          "502 TLS not available"
        end
      end

      def ehlo(data)
        resolve_hostname
        @helo_name = data.strip.split(" ", 2)[1]
        transaction_reset
        @state = :welcomed
        ["250-My capabilities are", Postal.config.smtp_server.tls_enabled? && !@tls ? "250-STARTTLS" : nil, "250 AUTH CRAM-MD5 PLAIN LOGIN",]
      end

      def helo(data)
        resolve_hostname
        @helo_name = data.strip.split(" ", 2)[1]
        transaction_reset
        @state = :welcomed
        "250 #{Postal.config.dns.smtp_server_hostname}"
      end

      def rset
        transaction_reset
        @state = :welcomed
        "250 OK"
      end

      def noop
        "250 OK"
      end

      def auth_plain(data)
        handler = Proc.new do |data|
          @proc = nil
          data = Base64.decode64(data)
          parts = data.split("\0")
          username, password = parts[-2], parts[-1]
          unless username && password
            next "535 Authenticated failed - protocol error"
          end

          authenticate(password)
        end

        data = data.gsub(/AUTH PLAIN ?/i, "")
        if data.strip == ""
          @proc = handler
          @password_expected_next = true
          "334"
        else
          handler.call(data)
        end
      end

      def auth_login(data)
        password_handler = Proc.new do |data|
          @proc = nil
          password = Base64.decode64(data)
          authenticate(password)
        end

        username_handler = Proc.new do
          @proc = password_handler
          @password_expected_next = true
          "334 UGFzc3dvcmQ6" # "Password:"
        end

        data = data.gsub!(/AUTH LOGIN ?/i, "")
        if data.strip == ""
          @proc = username_handler
          "334 VXNlcm5hbWU6" # "Username:"
        else
          username_handler.call(nil)
        end
      end

      def authenticate(password)
        if @credential = Credential.where(type: "SMTP", key: password).first
          @credential.use
          "235 Granted for #{@credential.server.organization.permalink}/#{@credential.server.permalink}"
        else
          log "\e[33m   WARN: AUTH failure for #{@ip_address}\e[0m"
          "535 Invalid credential"
        end
      end

      def auth_cram_md5(_data)
        challenge = Digest::SHA1.hexdigest(Time.now.to_i.to_s + rand(100_000).to_s)
        challenge = "<#{challenge[0, 20]}@#{Postal.config.dns.smtp_server_hostname}>"

        handler = Proc.new do |data|
          @proc = nil
          username, password = Base64.decode64(data).split(" ", 2).map { |a| a.chomp }
          org_permlink, server_permalink = username.split(/[\/_]/, 2)
          server = ::Server.includes(:organization).where(organizations: { permalink: org_permlink }, permalink: server_permalink).first
          next "535 Denied" if server.nil?

          grant = nil
          server.credentials.where(type: "SMTP").each do |credential|
            correct_response = OpenSSL::HMAC.hexdigest(CRAM_MD5_DIGEST, credential.key, challenge)
            if password == correct_response
              @credential = credential
              @credential.use
              grant = "235 Granted for #{credential.server.organization.permalink}/#{credential.server.permalink}"
              break
            end
          end
          grant || "535 Denied"
        end

        @proc = handler
        "334 " + Base64.encode64(challenge).gsub(/[\r\n]/, "")
      end

      def mail_from(data)
        unless in_state(:welcomed, :mail_from_received)
          return "503 EHLO/HELO first please"
        end

        @state = :mail_from_received
        transaction_reset
        if data =~ /AUTH=/
          # Discard AUTH= parameter and anything that follows.
          # We don't need this parameter as we don't trust any client to set it
          mail_from_line = data.sub(/ *AUTH=.*/, "")
        else
          mail_from_line = data
        end
        @mail_from = mail_from_line.gsub(/MAIL FROM\s*:\s*/i, "").gsub(/.*</, "").gsub(/>.*/, "").strip
        "250 OK"
      end

      def rcpt_to(data)
        unless in_state(:mail_from_received, :rcpt_to_received)
          return "503 EHLO/HELO and MAIL FROM first please"
        end

        rcpt_to = data.gsub(/RCPT TO\s*:\s*/i, "").gsub(/.*</, "").gsub(/>.*/, "").strip

        if rcpt_to.blank?
          return "501 RCPT TO should not be empty"
        end

        uname, domain = rcpt_to.split("@", 2)

        if domain.blank?
          return "501 Invalid RCPT TO"
        end

        uname, tag = uname.split("+", 2)

        if domain == Postal.config.dns.return_path || domain =~ /\A#{Regexp.escape(Postal.config.dns.custom_return_path_prefix)}\./
          # This is a return path
          @state = :rcpt_to_received
          if server = ::Server.where(token: uname).first
            if server.suspended?
              "535 Mail server has been suspended"
            else
              log "Added bounce on server #{server.id}"
              @recipients << [:bounce, rcpt_to, server]
              "250 OK"
            end
          else
            "550 Invalid server token"
          end

        elsif domain == Postal.config.dns.route_domain
          # This is an email direct to a route. This isn't actually supported yet.
          @state = :rcpt_to_received
          if route = Route.where(token: uname).first
            if route.server.suspended?
              "535 Mail server has been suspended"
            elsif route.mode == "Reject"
              "550 Route does not accept incoming messages"
            else
              log "Added route #{route.id} to recipients (tag: #{tag.inspect})"
              actual_rcpt_to = "#{route.name}" + (tag ? "+#{tag}" : "") + "@#{route.domain.name}"
              @recipients << [:route, actual_rcpt_to, route.server, route: route]
              "250 OK"
            end
          else
            "550 Invalid route token"
          end

        elsif @credential
          # This is outgoing mail for an authenticated user
          @state = :rcpt_to_received
          if @credential.server.suspended?
            "535 Mail server has been suspended"
          else
            log "Added external address '#{rcpt_to}'"
            @recipients << [:credential, rcpt_to, @credential.server]
            "250 OK"
          end

        elsif uname && domain && route = Route.find_by_name_and_domain(uname, domain)
          # This is incoming mail for a route
          @state = :rcpt_to_received
          if route.server.suspended?
            "535 Mail server has been suspended"
          elsif route.mode == "Reject"
            "550 Route does not accept incoming messages"
          else
            log "Added route #{route.id} to recipients (tag: #{tag.inspect})"
            @recipients << [:route, rcpt_to, route.server, route: route]
            "250 OK"
          end

        else
          # User is trying to relay but is not authenticated. Try to authenticate by IP address
          @credential = Credential.where(type: "SMTP-IP").all.sort_by { |c| c.ipaddr&.prefix || 0 }.reverse.find do |credential|
            credential.ipaddr.include?(@ip_address)
          end

          if @credential
            # Retry with credential
            @credential.use
            rcpt_to(data)
          else
            "530 Authentication required"
          end
        end
      end

      def data(_data)
        unless in_state(:rcpt_to_received)
          return "503 HELO/EHLO, MAIL FROM and RCPT TO before sending data"
        end

        @data = "".force_encoding("BINARY")
        @headers = {}
        @receiving_headers = true

        received_header_content = "from #{@helo_name} (#{@hostname} [#{@ip_address}]) by #{Postal.config.dns.smtp_server_hostname} with SMTP; #{Time.now.utc.rfc2822.to_s}".force_encoding("BINARY")
        if !Postal.config.smtp_server.strip_received_headers?
          @data << "Received: #{received_header_content}\r\n"
        end
        @headers["received"] = [received_header_content]

        handler = Proc.new do |data|
          if data == "."
            @logging_enabled = true
            @proc = nil
            finished
          else
            data = data.to_s.sub(/\A\.\./, ".")

            if @credential && @credential.server.log_smtp_data?
              # We want to log if enabled
            else
              log "Not logging further message data."
              @logging_enabled = false
            end

            if @receiving_headers
              if data.blank?
                @receiving_headers = false
              elsif data.to_s =~ /^\s/
                # This is a continuation of a header
                if @header_key && @headers[@header_key.downcase] && @headers[@header_key.downcase].last
                  @headers[@header_key.downcase].last << data.to_s
                end
                # If received headers are configured to be stripped and we're currently receiving one
                # skip the append methods at the bottom of this loop.
                next if Postal.config.smtp_server.strip_received_headers? && @header_key && @header_key.downcase == "received"
              else
                @header_key, value = data.split(/:\s*/, 2)
                @headers[@header_key.downcase] ||= []
                @headers[@header_key.downcase] << value
                # As above
                next if Postal.config.smtp_server.strip_received_headers? && @header_key && @header_key.downcase == "received"
              end
            end
            @data << data
            @data << "\r\n"
            nil
          end
        end

        @proc = handler
        "354 Go ahead"
      end

      def finished
        if @data.bytesize > Postal.config.smtp_server.max_message_size.megabytes.to_i
          transaction_reset
          @state = :welcomed
          return "552 Message too large (maximum size %dMB)" % Postal.config.smtp_server.max_message_size
        end

        if @headers["received"].select { |r| r =~ /by #{Postal.config.dns.smtp_server_hostname}/ }.count > 4
          transaction_reset
          @state = :welcomed
          return "550 Loop detected"
        end

        authenticated_domain = nil
        if @credential
          authenticated_domain = @credential.server.find_authenticated_domain_from_headers(@headers)
          if authenticated_domain.nil?
            transaction_reset
            @state = :welcomed
            return "530 From/Sender name is not valid"
          end
        end

        @recipients.each do |recipient|
          type, rcpt_to, server, options = recipient

          case type
          when :credential
            # Outgoing messages are just inserted
            message = server.message_db.new_message
            message.rcpt_to = rcpt_to
            message.mail_from = @mail_from
            message.raw_message = @data
            message.received_with_ssl = @tls
            message.scope = "outgoing"
            message.domain_id = authenticated_domain&.id
            message.credential_id = @credential.id
            message.save

          when :bounce
            if rp_route = server.routes.where(name: "__returnpath__").first
              # If there's a return path route, we can use this to create the message
              rp_route.create_messages do |message|
                message.rcpt_to = rcpt_to
                message.mail_from = @mail_from
                message.raw_message = @data
                message.received_with_ssl = @tls
              end
            else
              # There's no return path route, we just need to insert the mesage
              # without going through the route.
              message = server.message_db.new_message
              message.rcpt_to = rcpt_to
              message.mail_from = @mail_from
              message.raw_message = @data
              message.received_with_ssl = @tls
              message.scope = "incoming"
              message.bounce = 1
              message.save
            end
          when :route
            options[:route].create_messages do |message|
              message.rcpt_to = rcpt_to
              message.mail_from = @mail_from
              message.raw_message = @data
              message.received_with_ssl = @tls
            end
          end
        end
        transaction_reset
        @state = :welcomed
        "250 OK"
      end

      def in_state(*states)
        states.include?(@state)
      end

    end
  end
end
