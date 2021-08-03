module Postal
  module MessageDB
    module Migrations
      class ConvertDatabaseToUtf8mb4 < Postal::MessageDB::Migration

        def up
          @database.query("ALTER DATABASE `#{@database.database_name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
          @database.query("ALTER TABLE `#{@database.database_name}`.`clicks` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
          @database.query("ALTER TABLE `#{@database.database_name}`.`deliveries` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
          @database.query("ALTER TABLE `#{@database.database_name}`.`links` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
          @database.query("ALTER TABLE `#{@database.database_name}`.`live_stats` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
          @database.query("ALTER TABLE `#{@database.database_name}`.`loads` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
          @database.query("ALTER TABLE `#{@database.database_name}`.`messages` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
          @database.query("ALTER TABLE `#{@database.database_name}`.`migrations` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
          @database.query("ALTER TABLE `#{@database.database_name}`.`raw_message_sizes` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
          @database.query("ALTER TABLE `#{@database.database_name}`.`spam_checks` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
          @database.query("ALTER TABLE `#{@database.database_name}`.`stats_daily` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
          @database.query("ALTER TABLE `#{@database.database_name}`.`stats_hourly` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
          @database.query("ALTER TABLE `#{@database.database_name}`.`stats_monthly` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
          @database.query("ALTER TABLE `#{@database.database_name}`.`stats_yearly` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
          @database.query("ALTER TABLE `#{@database.database_name}`.`suppressions` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
          @database.query("ALTER TABLE `#{@database.database_name}`.`webhook_requests` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
        end

      end
    end
  end
end
