module Postal
  module MessageDB
    module Migrations
      class IncreaseLinksUrlSize < Postal::MessageDB::Migration

        def up
          @database.query("ALTER TABLE `#{@database.database_name}`.`links` MODIFY `url` TEXT")
        end

      end
    end
  end
end
