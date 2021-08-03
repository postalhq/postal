module Postal
  module MessageDB
    module Migrations
      class CreateMigrations < Postal::MessageDB::Migration

        def up
          @database.provisioner.create_table(:migrations,
                                             columns: {
                                               version: "int(11) NOT NULL"
                                             },
                                             primary_key: "`version`")
        end

      end
    end
  end
end
