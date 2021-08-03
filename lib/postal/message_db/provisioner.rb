module Postal
  module MessageDB
    class Provisioner

      def initialize(database)
        @database = database
      end

      #
      # Provisions a new database
      #
      def provision
        drop
        create
        migrate
      end

      #
      # Migrate this database
      #
      def migrate(start_from = @database.schema_version)
        Postal::MessageDB::Migration.run(@database, start_from)
      end

      #
      # Does a database already exist?
      #
      def exists?
        !!@database.query("SELECT schema_name FROM `information_schema`.`schemata` WHERE schema_name = '#{@database.database_name}'").first
      end

      #
      # Creates a new empty database
      #
      def create
        @database.query("CREATE DATABASE `#{@database.database_name}` CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;")
        true
      rescue Mysql2::Error => e
        e.message =~ /database exists/ ? false : raise
      end

      #
      # Drops the whole message database
      #
      def drop
        @database.query("DROP DATABASE `#{@database.database_name}`;")
        true
      rescue Mysql2::Error => e
        e.message =~ /doesn't exist/ ? false : raise
      end

      #
      # Create a new table
      #
      def create_table(table_name, options)
        @database.query(create_table_query(table_name, options))
      end

      #
      # Drop a table
      #
      def drop_table(table_name)
        @database.query("DROP TABLE `#{@database.database_name}`.`#{table_name}`")
      end

      #
      # Clean the database. This really only useful in development & testing
      # environment and can be quite dangerous in production.
      #
      def clean
        ["clicks", "deliveries", "links", "live_stats", "loads", "messages",
         "raw_message_sizes", "spam_checks", "stats_daily", "stats_hourly",
         "stats_monthly", "stats_yearly", "suppressions", "webhook_requests"].each do |table|
          @database.query("TRUNCATE `#{@database.database_name}`.`#{table}`")
        end
      end

      #
      # Creates a new empty raw message table for the given date. Returns nothing.
      #
      def create_raw_table(table)
        begin
          @database.query(create_table_query(table, columns: {
              id: "int(11) NOT NULL AUTO_INCREMENT",
              data: "longblob DEFAULT NULL",
              next: "int(11) DEFAULT NULL"
            }))
          @database.query("INSERT INTO `#{@database.database_name}`.`raw_message_sizes` (table_name, size) VALUES ('#{table}', 0)")
        rescue Mysql2::Error => e
          # Don't worry if the table already exists, another thread has already run this code.
          raise unless e.message =~ /already exists/
        end
      end

      #
      # Return a list of raw message tables that are older than the given date
      #
      def raw_tables(max_age = 30)
        earliest_date = max_age ? Date.today - max_age : nil
        [].tap do |tables|
          @database.query("SHOW TABLES FROM `#{@database.database_name}` LIKE 'raw-%'").each do |tbl|
            tbl_name = tbl.to_a.first.last
            date = Date.parse(tbl_name.gsub(/\Araw-/, ""))
            if earliest_date.nil? || date < earliest_date
              tables << tbl_name
            end
          end
        end.sort
      end

      #
      # Tidy all messages
      #
      def remove_raw_tables_older_than(max_age = 30)
        raw_tables(max_age).each do |table|
          remove_raw_table(table)
        end
      end

      #
      # Remove a raw message table
      #
      def remove_raw_table(table)
        @database.query("UPDATE `#{@database.database_name}`.`messages` SET raw_table = NULL, raw_headers_id = NULL, raw_body_id = NULL, size = NULL WHERE raw_table = '#{table}'")
        @database.query("DELETE FROM `#{@database.database_name}`.`raw_message_sizes` WHERE table_name = '#{table}'")
        drop_table(table)
      end

      #
      #  Remove messages from the messages table that are too old to retain
      #
      def remove_messages(max_age = 60)
        time = (Date.today - max_age.days).to_time.end_of_day
        if newest_message_to_remove = @database.select(:messages, where: { timestamp: { less_than_or_equal_to: time.to_f } }, limit: 1, order: :id, direction: "DESC", fields: [:id]).first
          id = newest_message_to_remove["id"]
          @database.query("DELETE FROM `#{@database.database_name}`.`clicks` WHERE `message_id` <= #{id}")
          @database.query("DELETE FROM `#{@database.database_name}`.`loads` WHERE `message_id` <= #{id}")
          @database.query("DELETE FROM `#{@database.database_name}`.`deliveries` WHERE `message_id` <= #{id}")
          @database.query("DELETE FROM `#{@database.database_name}`.`spam_checks` WHERE `message_id` <= #{id}")
          @database.query("DELETE FROM `#{@database.database_name}`.`messages` WHERE `id` <= #{id}")
        end
      end

      #
      # Remove raw message tables in order order until size is under the given size (given in MB)
      #
      def remove_raw_tables_until_less_than_size(size)
        tables = raw_tables(nil)
        tables_removed = []
        until @database.total_size <= size
          table = tables.shift
          tables_removed << table
          remove_raw_table(table)
        end
        tables_removed
      end

      private

      #
      # Build a query to load a table
      #
      def create_table_query(table_name, options)
        String.new.tap do |s|
          s << "CREATE TABLE `#{@database.database_name}`.`#{table_name}` ("
          s << options[:columns].map do |column_name, column_options|
            "`#{column_name}` #{column_options}"
          end.join(", ")
          if options[:indexes]
            s << ", "
            s << options[:indexes].map do |index_name, index_options|
              "KEY `#{index_name}` (#{index_options}) USING BTREE"
            end.join(", ")
          end
          if options[:unique_indexes]
            s << ", "
            s << options[:unique_indexes].map do |index_name, index_options|
              "UNIQUE KEY `#{index_name}` (#{index_options})"
            end.join(", ")
          end
          if options[:primary_key]
            s << ", PRIMARY KEY (#{options[:primary_key]})"
          else
            s << ", PRIMARY KEY (`id`)"
          end

          s << ") ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;"
        end
      end

    end
  end
end
