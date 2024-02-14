# frozen_string_literal: true

require "erb"
require "yaml"
require "pathname"
require "cgi"
require "openssl"
require "fileutils"
require_relative "error"
require_relative "version"

module Postal

  # rubocop:disable Lint/EmptyClass
  class Config
  end
  # rubocop:enable Lint/EmptyClass

  def self.host
    @host ||= config.web.host || "localhost:5000"
  end

  def self.protocol
    @protocol ||= config.web.protocol || "http"
  end

  def self.host_with_protocol
    @host_with_protocol ||= "#{protocol}://#{host}"
  end

  def self.app_root
    @app_root ||= Pathname.new(File.expand_path("../..", __dir__))
  end

  def self.config
    @config ||= begin
      require "hashie/mash"
      config = Hashie::Mash.new(defaults)
      config = config.deep_merge(yaml_config)
      config.deep_merge(local_yaml_config)
    end
  end

  def self.config_root
    if ENV["POSTAL_CONFIG_ROOT"]
      @config_root ||= Pathname.new(ENV["POSTAL_CONFIG_ROOT"])
    else
      @config_root ||= Pathname.new(File.expand_path("../../config/postal", __dir__))
    end
  end

  def self.config_file_path
    if env == "default"
      @config_file_path ||= File.join(config_root, "postal.yml")
    else
      @config_file_path ||= File.join(config_root, "postal.#{env}.yml")
    end
  end

  def self.env
    @env ||= ENV.fetch("POSTAL_ENV", "default")
  end

  def self.yaml_config
    @yaml_config ||= File.exist?(config_file_path) ? YAML.load_file(config_file_path) : {}
  end

  def self.local_config_file_path
    @local_config_file_path ||= File.join(config_root, "postal.local.yml")
  end

  def self.local_yaml_config
    @local_yaml_config ||= File.exist?(local_config_file_path) ? YAML.load_file(local_config_file_path) : {}
  end

  def self.defaults_file_path
    @defaults_file_path ||= app_root.join("config", "postal.defaults.yml")
  end

  def self.defaults
    @defaults ||= begin
      file = File.read(defaults_file_path)
      yaml = ERB.new(file).result
      YAML.safe_load(yaml)
    end
  end

  # Return a generic logger for use generally throughout Postal.
  #
  # @return [Klogger::Logger] A logger instance
  def self.logger
    @logger ||= begin
      k = Klogger.new(nil, destination: Rails.env.test? ? "/dev/null" : $stdout, highlight: Rails.env.development?)
      k.add_destination(graylog_logging_destination) if config.logging&.graylog&.host.present?
      k
    end
  end

  def self.process_name
    @process_name ||= begin
      string = "host:#{Socket.gethostname} pid:#{Process.pid}"
      string += " procname:#{ENV['PROC_NAME']}" if ENV["PROC_NAME"]
      string
    rescue StandardError
      "pid:#{Process.pid}"
    end
  end

  def self.locker_name
    string = process_name.dup
    string += " job:#{Thread.current[:job_id]}" if Thread.current[:job_id]
    string += " thread:#{Thread.current.native_thread_id}"
    string
  end

  def self.locker_name_with_suffix(suffix)
    "#{locker_name} #{suffix}"
  end

  def self.smtp_from_name
    config.smtp&.from_name || "Postal"
  end

  def self.smtp_from_address
    config.smtp&.from_address || "postal@example.com"
  end

  def self.smtp_private_key_path
    config.smtp_server.tls_private_key_path || config_root.join("smtp.key")
  end

  def self.smtp_private_key
    @smtp_private_key ||= OpenSSL::PKey.read(File.read(smtp_private_key_path))
  end

  def self.smtp_certificate_path
    config.smtp_server.tls_certificate_path || config_root.join("smtp.cert")
  end

  def self.smtp_certificate_data
    @smtp_certificate_data ||= File.read(smtp_certificate_path)
  end

  def self.smtp_certificates
    @smtp_certificates ||= begin
      certs = smtp_certificate_data.scan(/-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----/m)
      certs.map do |c|
        OpenSSL::X509::Certificate.new(c)
      end.freeze
    end
  end

  def self.signing_key_path
    ENV.fetch("POSTAL_SIGNING_KEY_PATH") { config_root.join("signing.key") }
  end

  def self.signing_key
    @signing_key ||= OpenSSL::PKey::RSA.new(File.read(signing_key_path))
  end

  def self.rp_dkim_dns_record
    public_key = signing_key.public_key.to_s.gsub(/-+[A-Z ]+-+\n/, "").gsub(/\n/, "")
    "v=DKIM1; t=s; h=sha256; p=#{public_key};"
  end

  class ConfigError < Postal::Error
  end

  def self.check_config!
    return if ENV["POSTAL_SKIP_CONFIG_CHECK"].to_i == 1

    unless File.exist?(config_file_path)
      raise ConfigError, "No config found at #{config_file_path}"
    end

    return if File.exist?(signing_key_path)

    raise ConfigError, "No signing key found at #{signing_key_path}"
  end

  def self.ip_pools?
    config.general.use_ip_pools?
  end

  def self.graylog_logging_destination
    @graylog_logging_destination ||= begin
      notifier = GELF::Notifier.new(config.logging.graylog.host, config.logging.graylog.port, "WAN")
      proc do |_logger, payload, group_ids|
        short_message = payload.delete(:message) || "[message missing]"
        notifier.notify!(short_message: short_message, **{
          facility: config.logging.graylog.facility,
          _environment: Rails.env.to_s,
          _version: Postal::VERSION.to_s,
          _group_ids: group_ids.join(" ")
        }.merge(payload.transform_keys { |k| "_#{k}".to_sym }.transform_values(&:to_s)))
      end
    end
  end

end
