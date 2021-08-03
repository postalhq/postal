#!/usr/bin/env ruby

# This script will insert a message into your database that looks like a bounce
# for a message that you specify.

# usage: insert-bounce.rb [serverid] [messageid]

if ARGV[0].nil? || ARGV[1].nil?
  puts "usage: #{__FILE__} [server-id] [message-id]"
  exit 1
end

require_relative "../config/environment"

server = Server.find(ARGV[0])
puts "Got server #{server.name}"

template = File.read(Rails.root.join("resource/postfix-bounce.msg"))

if ARGV[1].to_s =~ /\A(\d+)\z/
  message = server.message_db.message(ARGV[1].to_i)
  puts "Got message #{message.id} with token #{message.token}"
  template.gsub!("{{MSGID}}", message.token)
else
  template.gsub!("{{MSGID}}", ARGV[1].to_s)
end

message = server.message_db.new_message
message.scope = "incoming"
message.rcpt_to = "#{server.token}@#{Postal.config.dns.return_path}"
message.mail_from = "MAILER-DAEMON@smtp.infra.atech.io"
message.raw_message = template
message.bounce = 1
message.save
puts "Added message with id #{message.id}"
