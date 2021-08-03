module Postal
  module MessageDB
    module Migrations
      class CreateSuppressions < Postal::MessageDB::Migration

        def up
          @database.provisioner.create_table(:suppressions,
                                             columns: {
                                               id: "int(11) NOT NULL AUTO_INCREMENT",
                                               type: "varchar(255) DEFAULT NULL",
                                               address: "varchar(255) DEFAULT NULL",
                                               reason: "varchar(255) DEFAULT NULL",
                                               timestamp: "decimal(18,6) DEFAULT NULL",
                                               keep_until: "decimal(18,6) DEFAULT NULL"
                                             },
                                             indexes: {
                                               on_address: "`address`(6)",
                                               on_keep_until: "`keep_until`"
                                             })
        end

      end
    end
  end
end
