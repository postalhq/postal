require "logger"

module Postal

  class AppLogger < Logger

    def initialize(log_name, *args)
      @log_name = log_name
      super(*args)
      self.formatter = LogFormatter.new
    end

    def add(severity, message = nil, progname = nil)
      super
      if severity >= @level && n = self.class.graylog_notifier
        begin
          if message.nil?
            message = block_given? ? yield : progname
          end
          message = message.to_s.force_encoding("UTF-8").scrub
          message_without_ansi = message.gsub(/\e\[([\d;]+)?m/, "") rescue message
          n.notify!(short_message: message_without_ansi, log_name: @log_name, facility: "postal", application_name: "postal", process_name: ENV["PROC_NAME"], pid: Process.pid)
        rescue => e
          # Can't log this to GELF. Soz.
        end
      end
      true
    end

    def self.graylog?
      !!Postal.config.logging.graylog&.host
    end

    def self.graylog_notifier
      @graylog_notifier ||= graylog? ? GELF::Notifier.new(Postal.config.logging.graylog.host, Postal.config.logging.graylog.port) : nil
    end

  end

  class LogFormatter

    TIME_FORMAT = "%Y-%m-%dT%H:%M:%S.%3N".freeze
    COLORS = [32, 34, 35, 31, 32, 33]

    def call(severity, datetime, _progname, msg)
      time = datetime.strftime(TIME_FORMAT)
      if number = ENV["PROC_NAME"]
        id = number.split(".").last.to_i
        proc_text = "\e[#{COLORS[id % COLORS.size]}m[#{ENV['PROC_NAME']}:#{Process.pid}]\e[0m"
      else
        proc_text = "[#{Process.pid}]"
      end
      "#{proc_text} [#{time}] #{severity} -- : #{msg}\n"
    end

  end

end
