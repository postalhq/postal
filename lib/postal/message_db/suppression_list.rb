module Postal
  module MessageDB
    class SuppressionList

      def initialize(database)
        @database = database
      end

      def add(type, address, options = {})
        keep_until = (options[:days] || Postal.config.general.suppression_list_removal_delay).days.from_now.to_f
        if existing = @database.select("suppressions", where: { type: type, address: address }, limit: 1).first
          reason = options[:reason] || existing["reason"]
          @database.update("suppressions", { reason: reason, keep_until: keep_until }, where: { id: existing["id"] })
        else
          @database.insert("suppressions", { type: type, address: address, reason: options[:reason], timestamp: Time.now.to_f, keep_until: keep_until })
        end
        true
      end

      def get(type, address)
        @database.select("suppressions", where: { type: type, address: address, keep_until: { greater_than_or_equal_to: Time.now.to_f } }, limit: 1).first
      end

      def all_with_pagination(page)
        @database.select_with_pagination(:suppressions, page, order: :timestamp, direction: "desc")
      end

      def remove(type, address)
        @database.delete("suppressions", where: { type: type, address: address }) > 0
      end

      def prune
        @database.delete("suppressions", where: { keep_until: { less_than: Time.now.to_f } }) || 0
      end

    end
  end
end
