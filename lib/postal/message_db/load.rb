module Postal
  module MessageDB
    class Load

      def initialize(attributes)
        @ip_address = attributes["ip_address"]
        @user_agent = attributes["user_agent"]
        @timestamp = Time.zone.at(attributes["timestamp"])
      end

      attr_reader :ip_address
      attr_reader :user_agent
      attr_reader :timestamp

    end
  end
end
