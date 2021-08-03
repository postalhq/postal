require "net/http"

module Postal
  module MessageInspectors
    class Rspamd < MessageInspector

      class Error < StandardError
      end

      def inspect_message(inspection)
        response = request(inspection.message, inspection.scope)
        response = JSON.parse(response.body)
        return unless response["symbols"].is_a?(Hash)

        response["symbols"].values.each do |symbol|
          next if symbol["description"].blank?

          inspection.spam_checks << SpamCheck.new(symbol["name"], symbol["score"], symbol["description"])
        end
      rescue Error => e
        inspection.spam_checks << SpamCheck.new("ERROR", 0, e.message)
      end

      private

      def request(message, scope)
        http = Net::HTTP.new(@config.host, @config.port)
        http.use_ssl = true if @config.ssl
        http.read_timeout = 10
        http.open_timeout = 10

        raw_message = message.raw_message

        request = Net::HTTP::Post.new("/checkv2")
        request.body = raw_message
        request["Content-Length"] = raw_message.bytesize.to_s
        request["Password"] = @config.password if @config.password
        request["Flags"] = @config.flags if @config.flags
        request["User-Agent"] = "Postal"
        request["Deliver-To"] = message.rcpt_to
        request["From"] = message.mail_from
        request["Rcpt"] = message.rcpt_to
        request["Queue-Id"] = message.token

        if scope == :outgoing
          request["User"] = ""
          # We don't actually know the IP but an empty input here will
          # still trigger rspamd to treat this as an outbound email
          # and disable certain checks.
          # https://rspamd.com/doc/tutorials/scanning_outbound.html
          request["Ip"] = ""
        end

        response = nil
        begin
          response = http.request(request)
        rescue Exception => e
          logger.error "Error talking to rspamd: #{e.class} (#{e.message})"
          logger.error e.backtrace[0, 5]

          raise Error, "Error when scanning with rspamd (#{e.class})"
        end

        unless response.is_a?(Net::HTTPOK)
          logger.info "Got #{response.code} status from rspamd, wanted 200"
          raise Error, "Error when scanning with rspamd (got #{response.code})"
        end

        response
      end

    end
  end
end
