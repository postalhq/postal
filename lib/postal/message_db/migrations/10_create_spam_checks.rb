module Postal
  module MessageDB
    module Migrations
      class CreateSpamChecks < Postal::MessageDB::Migration

        def up
          @database.provisioner.create_table(:spam_checks,
                                             columns: {
                                               id: "int(11) NOT NULL AUTO_INCREMENT",
                                               message_id: "int(11) DEFAULT NULL",
                                               score: "decimal(8,2) DEFAULT NULL",
                                               code: "varchar(255) DEFAULT NULL",
                                               description: "varchar(255) DEFAULT NULL"
                                             },
                                             indexes: {
                                               on_message_id: "`message_id`",
                                               on_code: "`code`(8)"
                                             })
        end

      end
    end
  end
end
