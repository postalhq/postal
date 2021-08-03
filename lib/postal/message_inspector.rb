module Postal
  class MessageInspector

    def initialize(config)
      @config = config
    end

    # Inspect a message and update the inspection with the results
    # as appropriate.
    def inspect_message(message, scope, inspection)
    end

    private

    def logger
      Postal.logger_for(:message_inspection)
    end

    class << self

      # Return an array of all inspectors that are available for this
      # installation.
      def inspectors
        Array.new.tap do |inspectors|
          if Postal.config.rspamd&.enabled
            inspectors << MessageInspectors::Rspamd.new(Postal.config.rspamd)
          elsif Postal.config.spamd&.enabled
            inspectors << MessageInspectors::SpamAssassin.new(Postal.config.spamd)
          end

          if Postal.config.clamav&.enabled
            inspectors << MessageInspectors::Clamav.new(Postal.config.clamav)
          end
        end
      end

    end

  end
end
