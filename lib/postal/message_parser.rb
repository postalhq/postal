module Postal
  class MessageParser

    URL_REGEX = /(?<url>(?<protocol>https?):\/\/(?<domain>[A-Za-z0-9\-.:]+)(?<path>\/[A-Za-z0-9.\/+?&\-_%=~:;()\[\]#]*)?+)/

    def initialize(message)
      @message = message
      @actioned = false
      @tracked_links = 0
      @tracked_images = 0
      @domain = @message.server.track_domains.where(domain: @message.domain, dns_status: "OK").first

      if @domain
        @parsed_output = generate
      end
    end

    attr_reader :tracked_links
    attr_reader :tracked_images

    def actioned?
      @actioned || @tracked_links > 0 || @tracked_images > 0
    end

    def new_body
      @parsed_output.split("\r\n\r\n", 2)[1]
    end

    private

    def generate
      @mail = Mail.new(@message.raw_message)
      @original_message = @message.raw_message
      if @mail.parts.empty?
        if @mail.mime_type
          if @mail.mime_type =~ /text\/plain/
            @mail.body = parse(@mail.body.decoded.dup, :text)
            @mail.content_transfer_encoding = nil
            @mail.charset = "UTF-8"
          elsif @mail.mime_type =~ /text\/html/
            @mail.body = parse(@mail.body.decoded.dup, :html)
            @mail.content_transfer_encoding = nil
            @mail.charset = "UTF-8"
          end
        end
      else
        parse_parts(@mail.parts)
      end
      @mail.to_s
    rescue => e
      if Rails.env.development?
        raise
      else
        if defined?(Raven)
          Raven.capture_exception(e)
        end
        @actioned = false
        @tracked_links = 0
        @tracked_images = 0
        @original_message
      end
    end

    def parse_parts(parts)
      parts.each do |part|
        if part.content_type =~ /text\/html/
          part.body = parse(part.body.decoded.dup, :html)
          part.content_transfer_encoding = nil
          part.charset = "UTF-8"
        elsif part.content_type =~ /text\/plain/
          part.body = parse(part.body.decoded.dup, :text)
          part.content_transfer_encoding = nil
          part.charset = "UTF-8"
        elsif part.content_type =~ /multipart\/(alternative|related)/
          unless part.parts.empty?
            parse_parts(part.parts)
          end
        end
      end
    end

    def parse(part, type = nil)
      if @domain.track_clicks?
        part = insert_links(part, type)
      end

      if @domain.track_loads? && type == :html
        part = insert_tracking_image(part)
      end

      part
    end

    def insert_links(part, type = nil)
      if type == :text
        part.gsub!(/(#{URL_REGEX})(?=\s|$)/) do
          if track_domain?($~[:domain])
            @tracked_links += 1
            url = $~[:url]
            while url =~ /[^\w]$/ do
              theend = url.size - 2
              url = url[0..theend]
            end
            token = @message.create_link(url)
            "#{domain}/#{@message.server.token}/#{token}"
          else
            $&
          end
        end
      end

      if type == :html
        part.gsub!(/href=(['"])(#{URL_REGEX})['"]/) do
          if track_domain?($~[:domain])
            @tracked_links += 1
            token = @message.create_link($~[:url])
            "href='#{domain}/#{@message.server.token}/#{token}'"
          else
            $&
          end
        end
      end

      part.gsub!(/(https?)\+notrack:\/\//) do
        @actioned = true
        "#{$1}://"
      end

      part
    end

    def insert_tracking_image(part)
      @tracked_images += 1
      container = "<p class='ampimg' style='display:none;visibility:none;margin:0;padding:0;line-height:0;'><img src='#{domain}/img/#{@message.server.token}/#{@message.token}' alt=''></p>"
      if part =~ /<\/body>/
        part.gsub("</body>", "#{container}</body>")
      else
        part + container
      end
    end

    def domain
      "#{@domain.use_ssl? ? 'https' : 'http'}://#{@domain.full_name}"
    end

    def track_domain?(domain)
      !@domain.excluded_click_domains_array.include?(domain)
    end

  end
end
