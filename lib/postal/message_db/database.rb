module Postal
  module MessageDB
    class Database

      def initialize(organization_id, server_id)
        @organization_id = organization_id
        @server_id = server_id
      end

      attr_reader :organization_id
      attr_reader :server_id

      #
      # Return the server
      #
      def server
        @server ||= Server.find_by_id(@server_id)
      end

      #
      # Return the current schema version
      #
      def schema_version
        @schema_version ||= begin
          last_migration = select(:migrations, order: :version, direction: "DESC", limit: 1).first
          last_migration ? last_migration["version"] : 0
        rescue Mysql2::Error => e
          e.message =~ /doesn't exist/ ? 0 : raise
        end
      end

      #
      # Return a single message. Accepts an ID or an array of conditions
      #
      def message(*args)
        Message.find_one(self, *args)
      end

      #
      # Return an array or count of messages.
      #
      def messages(*args)
        Message.find(self, *args)
      end

      def messages_with_pagination(*args)
        Message.find_with_pagination(self, *args)
      end

      #
      #  Create a new message with the given attributes. This won't be saved to the database
      #  until it has been 'save'd.
      #
      def new_message(attributes = {})
        Message.new(self, attributes)
      end

      #
      # Return the total size of all stored messages
      #
      def total_size
        query("SELECT SUM(size) AS size FROM `#{database_name}`.`raw_message_sizes`").first["size"] || 0
      end

      #
      #  Return the live stats instance
      #
      def live_stats
        @live_stats ||= LiveStats.new(self)
      end

      #
      #  Return the statistics instance
      #
      def statistics
        @statistics ||= Statistics.new(self)
      end

      #
      #  Return the provisioner instance
      #
      def provisioner
        @provisioner ||= Provisioner.new(self)
      end

      #
      #  Return the provisioner instance
      #
      def suppression_list
        @suppression_list ||= SuppressionList.new(self)
      end

      #
      #  Return the provisioner instance
      #
      def webhooks
        @webhooks ||= Webhooks.new(self)
      end

      #
      # Return the name for a raw message table for a given date
      #
      def raw_table_name_for_date(date)
        date.strftime("raw-%Y-%m-%d")
      end

      #
      # Insert a new raw message into a table (creating it if needed)
      #
      def insert_raw_message(data, date = Date.today)
        table_name = raw_table_name_for_date(date)
        begin
          headers, body = data.split(/\r?\n\r?\n/, 2)
          headers_id = insert(table_name, data: headers)
          body_id = insert(table_name, data: body)
        rescue Mysql2::Error => e
          if e.message =~ /doesn't exist/
            provisioner.create_raw_table(table_name)
            retry
          else
            raise
          end
        end
        [table_name, headers_id, body_id]
      end

      #
      # Selects entries from the database. Accepts a number of options which can be used
      # to manipulate the results.
      #
      #   :where     => A hash containing the query
      #   :order     => The name of a field to order by
      #   :direction => The order that should be applied to ordering (ASC or DESC)
      #   :fields    => An array of fields to select
      #   :limit     => Limit the number of results
      #   :page      => Which page number to return
      #   :per_page  => The number of items per page (defaults to 30)
      #   :count     => Return a count of the results instead of the actual data
      #
      def select(table, options = {})
        sql_query = "SELECT"
        if options[:count]
          sql_query << " COUNT(id) AS count"
        elsif options[:fields]
          sql_query << " " + options[:fields].map { |f| "`#{f}`" }.join(", ")
        else
          sql_query << " *"
        end
        sql_query << " FROM `#{database_name}`.`#{table}`"
        if options[:where] && !options[:where].empty?
          sql_query << " " + build_where_string(options[:where], " AND ")
        end
        if options[:order]
          direction = (options[:direction] || "ASC").upcase
          raise Postal::Error, "Invalid direction #{options[:direction]}" unless ["ASC", "DESC"].include?(direction)

          sql_query << " ORDER BY `#{options[:order]}` #{direction}"
        end

        if options[:limit]
          sql_query << " LIMIT #{options[:limit]}"
        end

        if options[:offset]
          sql_query << " OFFSET #{options[:offset]}"
        end

        result = query(sql_query)
        if options[:count]
          result.first["count"]
        else
          result.to_a
        end
      end

      #
      #  A paginated version of select
      #
      def select_with_pagination(table, page, options = {})
        page = page.to_i
        page = 1 if page <= 0

        per_page = options.delete(:per_page) || 30
        offset = (page - 1) * per_page

        result = {}
        result[:total] = select(table, options.merge(count: true))
        result[:records] = select(table, options.merge(limit: per_page, offset: offset))
        result[:per_page] = per_page
        result[:total_pages], remainder = result[:total].divmod(per_page)
        result[:total_pages] += 1 if remainder > 0
        result[:page] = page
        result
      end

      #
      # Updates a record in the database. Accepts a table name, the attributes to update
      # plus some options which are shown below:
      #
      #   :where     => The condition to apply to the query
      #
      # Will return the total number of affected rows.
      #
      def update(table, attributes, options = {})
        sql_query = "UPDATE `#{database_name}`.`#{table}` SET"
        sql_query << " #{hash_to_sql(attributes)}"
        if options[:where]
          sql_query << " " + build_where_string(options[:where])
        end
        with_mysql do |mysql|
          query_on_connection(mysql, sql_query)
          mysql.affected_rows
        end
      end

      #
      # Insert a record into a given table. A hash of attributes is also provided.
      # Will return the ID of the new item.
      #
      def insert(table, attributes)
        sql_query = "INSERT INTO `#{database_name}`.`#{table}`"
        sql_query << " (" + attributes.keys.map { |k| "`#{k}`" }.join(", ") + ")"
        sql_query << " VALUES (" + attributes.values.map { |v| escape(v) }.join(", ") + ")"
        with_mysql do |mysql|
          query_on_connection(mysql, sql_query)
          mysql.last_id
        end
      end

      #
      # Insert multiple rows at the same time in the same query
      #
      def insert_multi(table, keys, values)
        if values.empty?
          nil
        else
          sql_query = "INSERT INTO `#{database_name}`.`#{table}`"
          sql_query << " (" + keys.map { |k| "`#{k}`" }.join(", ") + ")"
          sql_query << " VALUES "
          sql_query << values.map { |v| "(" + v.map { |v| escape(v) }.join(", ") + ")" }.join(", ")
          query(sql_query)
        end
      end

      #
      # Deletes a in the database. Accepts a table name, and some options which
      #  are shown below:
      #
      #   :where     => The condition to apply to the query
      #
      # Will return the total number of affected rows.
      #
      def delete(table, options = {})
        sql_query = "DELETE FROM `#{database_name}`.`#{table}`"
        sql_query << " " + build_where_string(options[:where], " AND ")
        with_mysql do |mysql|
          query_on_connection(mysql, sql_query)
          mysql.affected_rows
        end
      end

      #
      #  Return the correct database name
      #
      def database_name
        @database_name ||= "#{Postal.config.message_db.prefix}-server-#{@server_id}"
      end

      #
      # Run a query, log it and return the result
      #
      class ResultForExplainPrinter

        attr_reader :columns
        attr_reader :rows

        def initialize(result)
          if result.first
            @columns = result.first.keys
            @rows = result.map { |row| row.map(&:last) }
          else
            @columns = []
            @rows = []
          end
        end

      end

      def stringify_keys(hash)
        hash.each_with_object({}) do |(key, value), hash|
          hash[key.to_s] = value
        end
      end

      def escape(value)
        with_mysql do |mysql|
          if value == true
            "1"
          elsif value == false
            "0"
          elsif value.nil?
            "NULL"
          else
            if value.to_s.length == 0
              "NULL"
            else
              "'" + mysql.escape(value.to_s) + "'"
            end
          end
        end
      end

      def query(query)
        with_mysql do |mysql|
          query_on_connection(mysql, query)
        end
      end

      private

      def query_on_connection(connection, query)
        start_time = Time.now.to_f
        result = connection.query(query)
        time = Time.now.to_f - start_time
        logger.debug "  \e[4;34mMessageDB Query (#{time.round(2)}s) \e[0m  \e[33m#{query}\e[0m"
        if time > 0.5 && query =~ /\A(SELECT|UPDATE|DELETE) /
          id = Nifty::Utils::RandomString.generate(length: 6).upcase
          explain_result = ResultForExplainPrinter.new(connection.query("EXPLAIN #{query}"))
          slow_query_logger.info "[#{id}] EXPLAIN #{query}"
          for line in ActiveRecord::ConnectionAdapters::MySQL::ExplainPrettyPrinter.new.pp(explain_result, time).split("\n")
            slow_query_logger.info "[#{id}] " + line
          end
        end
        result
      end

      def logger
        defined?(Rails) ? Rails.logger : Logger.new($stdout)
      end

      def slow_query_logger
        Postal.logger_for(:slow_message_db_queries)
      end

      def with_mysql(&block)
        MessageDB::MySQL.client(&block)
      end

      def build_where_string(attributes, joiner = ", ")
        "WHERE #{hash_to_sql(attributes, joiner)}"
      end

      def hash_to_sql(hash, joiner = ", ")
        hash.map do |key, value|
          if value.is_a?(Array) && value.all? { |v| v.is_a?(Integer) }
            "`#{key}` IN (#{value.join(', ')})"
          elsif value.is_a?(Array)
            escaped_values = value.map { |v| escape(v) }.join(", ")
            "`#{key}` IN (#{escaped_values})"
          elsif value.is_a?(Hash)
            sql = []
            value.each do |operator, value|
              case operator
              when :less_than
                sql << "`#{key}` < #{escape(value)}"
              when :greater_than
                sql << "`#{key}` > #{escape(value)}"
              when :less_than_or_equal_to
                sql << "`#{key}` <= #{escape(value)}"
              when :greater_than_or_equal_to
                sql << "`#{key}` >= #{escape(value)}"
              end
            end
            sql.empty? ? "1=1" : sql.join(joiner)
          else
            "`#{key}` = #{escape(value)}"
          end
        end.join(joiner)
      end

    end
  end
end
