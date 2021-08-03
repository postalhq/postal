require "mail"
module Mail

  module Encodings

    # Handle windows-1258 as windows-1252 when decoding
    def Encodings.q_value_decode(str)
      str = str.sub(/=\?windows-?1258\?/i, '\=?windows-1252?')
      RubyVer.q_value_decode(str)
    end

    def Encodings.b_value_decode(str)
      str = str.sub(/=\?windows-?1258\?/i, '\=?windows-1252?')
      RubyVer.b_value_decode(str)
    end

  end

  class Message

    ## Extract plain text body of message
    def plain_body
      if multipart? and text_part
        text_part.decoded
      elsif mime_type == "text/plain" || mime_type.nil?
        decoded
      else
        nil
      end
    end

    ## Extract HTML text body of message
    def html_body
      if multipart? and html_part
        html_part.decoded
      elsif mime_type == "text/html"
        decoded
      else
        nil
      end
    end

    private

    ## Fix bug in basic parsing
    def parse_message
      self.header, self.body = raw_source.split(/\r?\n\r?\n/m, 2)
    end

    # Handle attached emails as attachments
    # Returns the filename of the attachment (if it exists) or returns nil
    # Make up a filename for rfc822 attachments if it isn't specified
    def find_attachment
      content_type_name = header[:content_type].filename rescue nil
      content_disp_name = header[:content_disposition].filename rescue nil
      content_loc_name = header[:content_location].location rescue nil

      if content_type && content_type_name
        filename = content_type_name
      elsif content_disposition && content_disp_name
        filename = content_disp_name
      elsif content_location && content_loc_name
        filename = content_loc_name
      elsif mime_type == "message/rfc822"
        filename = "#{rand(100_000_000)}.eml"
      else
        filename = nil
      end

      if filename
        # Normal decode
        filename = Mail::Encodings.decode_encode(filename, :decode) rescue filename
      end
      filename
    end

    def decode_body_as_text
      body_text = decode_body
      charset_tmp = Encoding.find(Ruby19.pick_encoding(charset)) rescue "ASCII"
      charset_tmp = "Windows-1252" if charset_tmp.to_s =~ /windows-?1258/i
      if charset_tmp == Encoding.find("UTF-7")
        body_text.force_encoding("UTF-8")
        decoded = body_text.gsub(/\+.*?-/m) { |n| Base64.decode64(n[1..-2] + "===").force_encoding("UTF-16BE").encode("UTF-8") }
      else
        body_text.force_encoding(charset_tmp)
        decoded = body_text.encode("utf-8", invalid: :replace, undef: :replace)
      end
      decoded.valid_encoding? ? decoded : decoded.encode("utf-16le", invalid: :replace, undef: :replace).encode("utf-8")
    end

  end

  # Handle attached emails as attachments
  class AttachmentsList < Array

    def initialize(parts_list)
      @parts_list = parts_list
      @content_disposition_type = "attachment"
      parts_list.map { |p|
        (p.parts.empty? and p.attachment?) ? p : p.attachments
      }.flatten.compact.each { |a| self << a }
      self
    end

  end

end

class Array

  def decoded
    return nil if empty?

    return first.decoded
  end

end

class NilClass

  def decoded
    nil
  end

end
