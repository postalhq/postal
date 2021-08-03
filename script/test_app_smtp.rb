#!/usr/bin/env ruby
trap("INT") { puts; exit }

if ARGV[0].nil? || !(ARGV[0] =~ /@/)
  puts "usage: postal test-app-smtp [email address]"
  exit 1
end

require_relative "../config/environment"

begin
  Timeout.timeout(10) do
    AppMailer.test_message(ARGV[0]).deliver
  end

  puts "\e[32mMessage has been sent successfully.\e[0m"
rescue => e
  puts "\e[31mMessage was not delivered successfully to SMTP server.\e[0m"
  puts "Error: #{e.class} (#{e.message})"
  puts
  puts "  SMTP Host: #{Postal.config.smtp.host}"
  puts "  SMTP Port: #{Postal.config.smtp.port}"
  puts "  SMTP Username: #{Postal.config.smtp.username}"
  puts "  SMTP Password: #{Postal.config.smtp.password}"
  puts
rescue Timeout::Error
  puts "Sending timed out"
end
