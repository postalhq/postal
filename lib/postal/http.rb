require "net/https"
require "uri"

module Postal
  module HTTP

    def self.get(url, options = {})
      request(Net::HTTP::Get, url, options)
    end

    def self.post(url, options = {})
      request(Net::HTTP::Post, url, options)
    end

    def self.request(method, url, options = {})
      options[:headers] ||= {}
      uri = URI.parse(url)
      request = method.new((uri.path.length == 0 ? "/" : uri.path) + (uri.query ? "?" + uri.query : ""))
      options[:headers].each { |k, v| request.add_field k, v }

      if options[:username] || uri.user
        request.basic_auth(options[:username] || uri.user, options[:password] || uri.password)
      end

      if options[:params].is_a?(Hash)
        # If params has been provided, sent it them as form encoded values
        request.set_form_data(options[:params])

      elsif options[:json].is_a?(String)
        # If we have a JSON string, set the content type and body to be the JSON
        # data
        request.add_field "Content-Type", "application/json"
        request.body = options[:json]

      elsif options[:text_body]
        # Add a plain text body if we have one
        request.body = options[:text_body]
      end

      if options[:sign]
        signature = EncryptoSigno.sign(Postal.signing_key, request.body.to_s).gsub("\n", "")
        request.add_field "X-Postal-Signature", signature
      end

      request["User-Agent"] = options[:user_agent] || "Postal/#{Postal.version}"

      connection = Net::HTTP.new(uri.host, uri.port)

      if uri.scheme == "https"
        connection.use_ssl = true
        connection.verify_mode = OpenSSL::SSL::VERIFY_PEER
        ssl = true
      else
        ssl = false
      end

      begin
        timeout = options[:timeout] || 60
        Timeout.timeout(timeout) do
          result = connection.request(request)
          {
            code: result.code.to_i,
            body: result.body,
            headers: result.to_hash,
            secure: @ssl
          }
        end
      rescue OpenSSL::SSL::SSLError => e
        {
          code: -3,
          body: "Invalid SSL certificate",
          headers: {},
          secure: @ssl
        }
      rescue SocketError, Errno::ECONNRESET, EOFError, Errno::EINVAL, Errno::ENETUNREACH, Errno::EHOSTUNREACH, Errno::ECONNREFUSED => e
        {
          code: -2,
          body: e.message,
          headers: {},
          secure: @ssl
        }
      rescue Timeout::Error => e
        {
          code: -1,
          body: "Timed out after #{timeout}s",
          headers: {},
          secure: @ssl
        }
      end
    end

  end
end
