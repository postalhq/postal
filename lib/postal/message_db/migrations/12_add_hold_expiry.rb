module Postal
  module MessageDB
    module Migrations
      class AddHoldExpiry < Postal::MessageDB::Migration

        def up
          @database.query("ALTER TABLE `#{@database.database_name}`.`messages` ADD COLUMN `hold_expiry` decimal(18,6)")
        end

      end
    end
  end
end
