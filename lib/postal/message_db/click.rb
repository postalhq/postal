module Postal
  module MessageDB
    class Click

      def initialize(attributes, link)
        @url = link["url"]
        @ip_address = attributes["ip_address"]
        @user_agent = attributes["user_agent"]
        @timestamp = Time.zone.at(attributes["timestamp"])
      end

      attr_reader :ip_address
      attr_reader :user_agent
      attr_reader :timestamp
      attr_reader :url

    end
  end
end
