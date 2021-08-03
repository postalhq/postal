module Postal
  module MessageDB
    module Migrations
      class CreateDeliveries < Postal::MessageDB::Migration

        def up
          @database.provisioner.create_table(:deliveries,
                                             columns: {
                                               id: "int(11) NOT NULL AUTO_INCREMENT",
                                               message_id: "int(11) DEFAULT NULL",
                                               status: "varchar(255) DEFAULT NULL",
                                               code: "int(11) DEFAULT NULL",
                                               output: "varchar(512) DEFAULT NULL",
                                               details: "varchar(512) DEFAULT NULL",
                                               sent_with_ssl: "tinyint(1) DEFAULT 0",
                                               log_id: "varchar(100) DEFAULT NULL",
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
