#!/usr/bin/env ruby
require File.expand_path("../../lib/postal/config", __FILE__)
require "openssl"
require "securerandom"
require "fileutils"

unless File.directory?(Postal.config_root)
  FileUtils.mkdir_p(Postal.config_root)
end

unless File.exist?(Postal.config_file_path)
  content = File.read(Postal.app_root.join("config", "postal.example.yml"))
  content.gsub!("{{secretkey}}", SecureRandom.hex(128))
  File.open(Postal.config_file_path, "w") { |f| f.write(content) }
  puts "Created example config file at #{Postal.config_file_path}"
end

unless File.exist?(Postal.signing_key_path)
  key = OpenSSL::PKey::RSA.new(1024).to_s
  File.open(Postal.signing_key_path, "w") { |f| f.write(key) }
  puts "Created new signing key for DKIM & HTTP requests"
end
