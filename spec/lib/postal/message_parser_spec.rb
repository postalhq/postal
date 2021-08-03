require "rails_helper"

describe Postal::MessageParser do
  it "should not do anything when there are no tracking domains" do
    with_global_server do |server|
      expect(server.track_domains.size).to eq 0
      message = create_plain_text_message(server, "Hello world!", "test@example.com")
      parser = Postal::MessageParser.new(message)
      expect(parser.actioned?).to be false
      expect(parser.tracked_links).to eq 0
      expect(parser.tracked_images).to eq 0
    end
  end

  it "should replace links in messages" do
    with_global_server do |server|
      message = create_plain_text_message(server, "Hello world! http://github.com/atech/postal", "test@example.com")
      track_domain = create(:track_domain, server: server, domain: message.domain)
      parser = Postal::MessageParser.new(message)
      expect(parser.actioned?).to be true
      expect(parser.new_body).to match(/\AHello world! https:\/\/click\.#{message.domain.name}/)
      expect(parser.tracked_links).to eq 1
    end
  end
end
