module Postal
  module MessageDB
    class Statistics

      def initialize(database)
        @database = database
      end

      STATS_GAPS = { hourly: :hour, daily: :day, monthly: :month, yearly: :year }
      COUNTERS = [:incoming, :outgoing, :spam, :bounces, :held]

      #
      # Increment an appropriate counter
      #
      def increment_one(type, field, time = Time.now)
        time = time.utc
        initial_values = COUNTERS.map do |c|
          field.to_sym == c ? 1 : 0
        end

        time_i = time.send("beginning_of_#{STATS_GAPS[type]}").utc.to_i
        sql_query = "INSERT INTO `#{@database.database_name}`.`stats_#{type}` (time, #{COUNTERS.join(', ')})"
        sql_query << " VALUES (#{time_i}, #{initial_values.join(', ')})"
        sql_query << " ON DUPLICATE KEY UPDATE #{field} = #{field} + 1"
        @database.query(sql_query)
      end

      #
      # Increment all stats counters
      #
      def increment_all(time, field)
        STATS_GAPS.keys.each do |type|
          increment_one(type, field, time)
        end
      end

      #
      # Get a statistic (or statistics)
      #
      def get(type, counters, start_date = Time.now, quantity = 10)
        date = start_date.utc
        items = quantity.times.each_with_object({}) do |i, hash|
          hash[(start_date - i.send(STATS_GAPS[type])).send("beginning_of_#{STATS_GAPS[type]}").utc] = counters.each_with_object({}) do |c, h|
            h[c] = 0
          end
        end
        @database.select("stats_#{type}", where: { time: items.keys.map(&:to_i) }, fields: [:time] | counters).each do |data|
          time = Time.zone.at(data.delete("time"))
          data.each do |key, value|
            items[time][key.to_sym] = value
          end
        end
        items.to_a.reverse
      end

    end
  end
end
