module Postal
  module MessageDB
    module Migrations
      class CreateStats < Postal::MessageDB::Migration

        def up
          [:hourly, :daily, :monthly, :yearly].each do |table_name|
            @database.provisioner.create_table("stats_#{table_name}",
                                               columns: {
                                                 id: "int(11) NOT NULL AUTO_INCREMENT",
                                                 time: "int(11) DEFAULT NULL",
                                                 incoming: "bigint DEFAULT NULL",
                                                 outgoing: "bigint DEFAULT NULL",
                                                 spam: "bigint DEFAULT NULL",
                                                 bounces: "bigint DEFAULT NULL",
                                                 held: "bigint DEFAULT NULL"
                                               },
                                               unique_indexes: {
                                                 on_time: "`time`"
                                               })
          end
        end

      end
    end
  end
end
