module Postal
  module MessageDB
    module Migrations
      class CreateMessages < Postal::MessageDB::Migration

        def up
          @database.provisioner.create_table(:messages,
                                             columns: {
                                               id: "int(11) NOT NULL AUTO_INCREMENT",
                                               token: "varchar(255) DEFAULT NULL",
                                               scope: "varchar(10) DEFAULT NULL",
                                               rcpt_to: "varchar(255) DEFAULT NULL",
                                               mail_from: "varchar(255) DEFAULT NULL",
                                               subject: "varchar(255) DEFAULT NULL",
                                               message_id: "varchar(255) DEFAULT NULL",
                                               timestamp: "decimal(18,6) DEFAULT NULL",
                                               route_id: "int(11) DEFAULT NULL",
                                               domain_id: "int(11) DEFAULT NULL",
                                               credential_id: "int(11) DEFAULT NULL",
                                               status: "varchar(255) DEFAULT NULL",
                                               held: "tinyint(1) DEFAULT 0",
                                               size: "varchar(255) DEFAULT NULL",
                                               last_delivery_attempt: "decimal(18,6) DEFAULT NULL",
                                               raw_table: "varchar(255) DEFAULT NULL",
                                               raw_body_id: "int(11) DEFAULT NULL",
                                               raw_headers_id: "int(11) DEFAULT NULL",
                                               inspected: "tinyint(1) DEFAULT 0",
                                               spam: "tinyint(1) DEFAULT 0",
                                               spam_score: "decimal(8,2) DEFAULT 0",
                                               threat: "tinyint(1) DEFAULT 0",
                                               threat_details: "varchar(255) DEFAULT NULL",
                                               bounce: "tinyint(1) DEFAULT 0",
                                               bounce_for_id: "int(11) DEFAULT 0",
                                               tag: "varchar(255) DEFAULT NULL",
                                               loaded: "decimal(18,6) DEFAULT NULL",
                                               clicked: "decimal(18,6) DEFAULT NULL",
                                               received_with_ssl: "tinyint(1) DEFAULT NULL"
                                             },
                                             indexes: {
                                               on_message_id: "`message_id`(8)",
                                               on_token: "`token`(6)",
                                               on_bounce_for_id: "`bounce_for_id`",
                                               on_held: "`held`",
                                               on_scope_and_status: "`scope`(1), `spam`, `status`(6), `timestamp`",
                                               on_scope_and_tag: "`scope`(1), `spam`, `tag`(8), `timestamp`",
                                               on_scope_and_spam: "`scope`(1), `spam`, `timestamp`",
                                               on_scope_and_thr_status: "`scope`(1), `threat`, `status`(6), `timestamp`",
                                               on_scope_and_threat: "`scope`(1), `threat`, `timestamp`",
                                               on_rcpt_to: "`rcpt_to`(12), `timestamp`",
                                               on_mail_from: "`mail_from`(12), `timestamp`",
                                               on_raw_table: "`raw_table`(14)"
                                             })
        end

      end
    end
  end
end
