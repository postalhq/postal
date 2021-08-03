module Postal
  module MessageDB
    class LiveStats

      def initialize(database)
        @database = database
      end

      #
      # Increment the live stats by one for the current minute
      #
      def increment(type)
        time = Time.now.utc
        type = @database.escape(type.to_s)
        sql_query = "INSERT INTO `#{@database.database_name}`.`live_stats` (type, minute, timestamp, count)"
        sql_query << " VALUES (#{type}, #{time.min}, #{time.to_f}, 1)"
        sql_query << " ON DUPLICATE KEY UPDATE count = if(timestamp < #{time.to_f - 1800}, 1, count + 1), timestamp = #{time.to_f}"
        @database.query(sql_query)
      end

      #
      # Return the total number of messages for the last 60 minutes
      #
      def total(minutes, options = {})
        if minutes > 60
          raise Postal::Error, "Live stats can only return data for the last 60 minutes."
        end

        options[:types] ||= [:incoming, :outgoing]
        if options[:types].empty?
          raise Postal::Error, "You must provide at least one type to return"
        else
          time = minutes.minutes.ago.beginning_of_minute.utc.to_f
          types = options[:types].map { |t| "#{@database.escape(t.to_s)}" }.join(", ")
          result = @database.query("SELECT SUM(count) as count FROM `#{@database.database_name}`.`live_stats` WHERE `type` IN (#{types}) AND timestamp > #{time}").first
          result["count"] || 0
        end
      end

    end
  end
end
