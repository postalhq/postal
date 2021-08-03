module Postal
  module MessageDB
    module Migrations
      class AddUrlAndHookToWebhooks < Postal::MessageDB::Migration

        def up
          @database.query("ALTER TABLE `#{@database.database_name}`.`webhook_requests` ADD COLUMN `url` varchar(255)")
          @database.query("ALTER TABLE `#{@database.database_name}`.`webhook_requests` ADD COLUMN `webhook_id` int(11)")
          @database.query("ALTER TABLE `#{@database.database_name}`.`webhook_requests` ADD INDEX `on_webhook_id` (`webhook_id`) USING BTREE")
        end

      end
    end
  end
end
