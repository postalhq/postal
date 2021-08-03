module Postal
  module MessageDB
    module Migrations
      class CreateLoads < Postal::MessageDB::Migration

        def up
          @database.provisioner.create_table(:loads,
                                             columns: {
                                               id: "int(11) NOT NULL AUTO_INCREMENT",
                                               message_id: "int(11) DEFAULT NULL",
                                               ip_address: "varchar(255) DEFAULT NULL",
                                               country: "varchar(255) DEFAULT NULL",
                                               city: "varchar(255) DEFAULT NULL",
                                               user_agent: "varchar(255) DEFAULT NULL",
                                               timestamp: "decimal(18,6) DEFAULT NULL"
                                             },
                                             indexes: {
                                               on_message_id: "`message_id`"
                                             })
        end

      end
    end
  end
end
