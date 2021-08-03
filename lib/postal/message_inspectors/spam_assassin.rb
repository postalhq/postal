module Postal
  module MessageInspectors
    class SpamAssassin < MessageInspector

      EXCLUSIONS = {
        outgoing: ["NO_RECEIVED", "NO_RELAYS", "ALL_TRUSTED", "FREEMAIL_FORGED_REPLYTO", "RDNS_DYNAMIC", "CK_HELO_GENERIC", /^SPF_/, /^HELO_/, /DKIM_/, /^RCVD_IN_/],
        incoming: []
      }

      def inspect_message(inspection)
        data = nil
        raw_message = inspection.message.raw_message
        Timeout.timeout(15) do
          tcp_socket = TCPSocket.new(@config.host, @config.port)
          tcp_socket.write("REPORT SPAMC/1.2\r\n")
          tcp_socket.write("Content-length: #{raw_message.bytesize}\r\n")
          tcp_socket.write("\r\n")
          tcp_socket.write(raw_message)
          tcp_socket.close_write
          data = tcp_socket.read
        end

        spam_checks = []
        total = 0.0
        rules = data ? data.split(/^---(.*)\r?\n/).last.split(/\r?\n/) : []
        while line = rules.shift
          if line =~ /\A([\- ]?[\d.]+)\s+(\w+)\s+(.*)/
            total += $1.to_f
            spam_checks << SpamCheck.new($2, $1.to_f, $3)
          else
            spam_checks.last.description << " " + line.strip
          end
        end

        checks = spam_checks.reject { |s| EXCLUSIONS[inspection.scope].include?(s.code) }
        checks.each do |check|
          inspection.spam_checks << check
        end
      rescue Timeout::Error
        inspection.spam_checks << SpamCheck.new("TIMEOUT", 0, "Timed out when scanning for spam")
      rescue => e
        logger.error "Error talking to spamd: #{e.class} (#{e.message})"
        logger.error e.backtrace[0, 5]
        inspection.spam_checks << SpamCheck.new("ERROR", 0, "Error when scanning for spam")
      ensure
        tcp_socket.close rescue nil
      end

    end
  end
end
