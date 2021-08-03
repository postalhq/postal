require "postal/config"
require "bunny"

module Postal
  module RabbitMQ

    def self.create_connection
      bunny_host = ["localhost"]

      if Postal.config.rabbitmq&.host.is_a?(Array)
        bunny_host = Postal.config.rabbitmq&.host
      elsif Postal.config.rabbitmq&.host.is_a?(String)
        bunny_host = [Postal.config.rabbitmq&.host]
      end

      conn = Bunny.new(
        hosts: bunny_host,
        port: Postal.config.rabbitmq&.port || 5672,
        username: Postal.config.rabbitmq&.username || "guest",
        password: Postal.config.rabbitmq&.password || "guest",
        vhost: Postal.config.rabbitmq&.vhost || nil
      )
      conn.start
      conn
    end

    def self.create_channel
      conn = create_connection
      conn.create_channel(nil, Postal.config.workers.threads)
    end

  end
end
