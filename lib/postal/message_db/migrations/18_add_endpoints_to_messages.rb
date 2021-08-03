module Postal
  module MessageDB
    module Migrations
      class AddEndpointsToMessages < Postal::MessageDB::Migration

        def up
          @database.query("ALTER TABLE `#{@database.database_name}`.`messages` ADD COLUMN `endpoint_id` int(11), ADD COLUMN `endpoint_type` varchar(255)")
        end

      end
    end
  end
end
