module Postal
  module MessageDB
    class Webhooks

      def initialize(database)
        @database = database
      end

      def record(attributes = {})
        @database.insert(:webhook_requests, attributes)
      end

      def list(page)
        result = @database.select_with_pagination(:webhook_requests, page, order: :timestamp, direction: "desc")
        result[:records] = result[:records].map { |i| Request.new(i) }
        result
      end

      def find(uuid)
        request = @database.select(:webhook_requests, where: { uuid: uuid }).first || raise(RequestNotFound, "No request found with UUID '#{uuid}'")
        Request.new(request)
      end

      def prune
        if last = @database.select(:webhook_requests, where: { timestamp: { less_than: 10.days.ago.to_f } }, order: "timestamp", direction: "desc", limit: 1, fields: ["id"]).first
          @database.delete(:webhook_requests, where: { id: { less_than_or_equal_to: last["id"] } })
        end
      end

      class RequestNotFound < Postal::Error
      end

      class Request

        def initialize(attributes)
          @attributes = attributes
        end

        def [](name)
          @attributes[name.to_s]
        end

        def timestamp
          Time.zone.at(@attributes["timestamp"])
        end

        def event
          @attributes["event"]
        end

        def status_code
          @attributes["status_code"]
        end

        def url
          @attributes["url"]
        end

        def uuid
          @attributes["uuid"]
        end

        def payload
          @attributes["payload"]
        end

        def pretty_payload
          @pretty_payload ||= begin
            json = JSON.parse(payload)
            JSON.pretty_unparse(json)
          end
        end

        def body
          @attributes["body"]
        end

        def attempt
          @attributes["attempt"]
        end

        def will_retry?
          @attributes["will_retry"] == 1
        end

      end

    end
  end
end
