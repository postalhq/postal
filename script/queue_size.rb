#!/usr/bin/env ruby
require_relative "../lib/postal/config"
require "mysql2"

client = Mysql2::Client.new(host: Postal.config.main_db.host, username: Postal.config.main_db.username, password: Postal.config.main_db.password, port: Postal.config.main_db.port, database: Postal.config.main_db.database)
result = client.query("SELECT COUNT(id) as size FROM `queued_messages` WHERE retry_after IS NULL OR retry_after <= ADDTIME(UTC_TIMESTAMP(), '30') AND locked_at IS NULL")
puts result.to_a.first["size"]
