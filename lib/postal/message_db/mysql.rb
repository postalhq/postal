module Postal
  module MessageDB
    module MySQL

      # This exists here because it needs to be required when the application loads
      # so that it isn't unloaded in development. If it was unloaded in development,
      # it would be undesirable as we'd just end up with lots of connections.

      def self.new_client
        Mysql2::Client.new(host: Postal.config.message_db.host, username: Postal.config.message_db.username, password: Postal.config.message_db.password, port: Postal.config.message_db.port, reconnect: true, encoding: Postal.config.message_db.encoding || "utf8mb4")
      end

      @free_clients = []

      def self.client(&block)
        client = @free_clients.shift || new_client
        return_value = nil
        tries = 2
        begin
          return_value = block.call(client)
        rescue Mysql2::Error => e
          if e.message =~ /(lost connection|gone away)/i && (tries -= 1) > 0
            retry
          else
            raise
          end
        ensure
          @free_clients << client
        end
        return_value
      end

    end
  end
end
