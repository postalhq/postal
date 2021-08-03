module Postal
  class DKIMHeader

    def initialize(domain, message)
      if domain && domain.dkim_status == "OK"
        @domain_name = domain.name
        @dkim_key = domain.dkim_key
        @dkim_identifier = domain.dkim_identifier
      else
        @domain_name = Postal.config.dns.return_path
        @dkim_key = Postal.signing_key
        @dkim_identifier = "postal"
      end
      @domain = domain
      @message = message
      @raw_headers, @raw_body = @message.gsub(/\r?\n/, "\r\n").split(/\r\n\r\n/, 2)
    end

    def dkim_header
      "DKIM-Signature: v=1; " + dkim_properties.join("\r\n\t") + signature.scan(/.{1,72}/).join("\r\n\t")
    end

    private

    def headers
      @headers ||= @raw_headers.to_s.gsub(/\r?\n\s/, " ").split(/\r?\n/)
    end

    def header_names
      normalized_headers.map { |h| h.split(":")[0].strip }
    end

    def normalized_headers
      Array.new.tap do |new_headers|
        headers.select { |h| h.match(/^(from|sender|reply-to|subject|date|message-id|to|cc|mime-version|content-type|content-transfer-encoding|resent-to|resent-cc|resent-from|resent-sender|resent-message-id|in-reply-to|references|list-id|list-help|list-owner|list-unsubscribe|list-subscribe|list-post):/i) }.each do |h|
          new_headers << normalize_header(h)
        end
      end
    end

    def normalize_header(content)
      content = content.dup

      # From the DKIM RFC6376
      # https://datatracker.ietf.org/doc/html/rfc6376#section-3.4.2

      # Split the key and value.
      key, value = content.split(":", 2)

      # Convert all header field names (not the header field values) to
      # lowercase.  For example, convert "SUBJect: AbC" to "subject: AbC".
      key.downcase!

      # Unfold all header field continuation lines as described in [RFC5322]
      value.gsub!(/\r?\n[ \t]+/, " ")

      # Convert all sequences of one or more WSP characters to a single SP character.
      value.gsub!(/[ \t]+/, " ")

      # Delete all WSP characters at the end of each unfolded header field value.
      value.gsub!(/[ \t]*\z/, "")

      # Delete any WSP characters remaining after the colon separating the header field name from the header field value.
      value.gsub!(/\A[ \t]*/, "")

      # Join together
      key + ":" + value
    end

    def normalized_body
      @normalized_body ||= begin
        content = @raw_body.dup

        # From the DKIM RFC6376
        # https://datatracker.ietf.org/doc/html/rfc6376#section-3.4.4

        # a. Reduce whitespace
        #
        # * Reduce all sequences of WSP within a line to a single SP character.
        content.gsub!(/[ \t]+/, " ")

        # * Ignore all whitespace at the end of lines.  Implementations MUST NOT
        #   remove the CRLF at the end of the line.
        content.gsub!(/ \r\n/, "\r\n")

        # b. Ignore all empty lines at the end of the message body.
        content.gsub!(/[ \r\n]*\z/, "")

        content += "\r\n"
        content
      end
    end

    def body_hash
      @body_hash ||= Base64.encode64(Digest::SHA256.digest(normalized_body)).strip
    end

    def dkim_properties
      Array.new.tap do |header|
        header << "a=rsa-sha256; c=relaxed/relaxed;"
        header << "d=#{@domain_name};"
        header << "s=#{@dkim_identifier}; t=#{Time.now.utc.to_i};"
        header << "bh=#{body_hash};"
        header << "h=#{header_names.join(':')};"
        header << "b="
      end
    end

    def dkim_header_for_signing
      "dkim-signature:v=1; #{dkim_properties.join(' ')}"
    end

    def signable_header_string
      (normalized_headers + [dkim_header_for_signing]).join("\r\n")
    end

    def signature
      Base64.encode64(@dkim_key.sign(OpenSSL::Digest.new('SHA256'), signable_header_string)).gsub("\n", "")
    end

  end
end
