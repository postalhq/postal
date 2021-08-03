module Postal
  module MessageDB
    module Migrations
      class CreateWebhookRequests < Postal::MessageDB::Migration

        def up
          @database.provisioner.create_table(:webhook_requests,
                                             columns: {
                                               id: "int(11) NOT NULL AUTO_INCREMENT",
                                               uuid: "varchar(255) DEFAULT NULL",
                                               event: "varchar(255) DEFAULT NULL",
                                               attempt: "int(11) DEFAULT NULL",
                                               timestamp: "decimal(18,6) DEFAULT NULL",
                                               status_code: "int(1) DEFAULT NULL",
                                               body: "text DEFAULT NULL",
                                               payload: "text DEFAULT NULL",
                                               will_retry: "tinyint DEFAULT NULL"
                                             },
                                             indexes: {
                                               on_uuid: "`uuid`(8)",
                                               on_event: "`event`(8)",
                                               on_timestamp: "`timestamp`"
                                             })
        end

      end
    end
  end
end
