module Postal
  module MessageDB
    module Migrations
      class AddTimeToDeliveries < Postal::MessageDB::Migration

        def up
          @database.query("ALTER TABLE `#{@database.database_name}`.`deliveries` ADD COLUMN `time` decimal(8,2)")
        end

      end
    end
  end
end
