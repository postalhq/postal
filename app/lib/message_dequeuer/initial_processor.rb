# frozen_string_literal: true

module MessageDequeuer
  class InitialProcessor < Base

    include HasPrometheusMetrics

    attr_accessor :send_result

    def process
      logger.tagged(original_queued_message: @queued_message.id) do
        logger.info "starting message unqueue"
        begin
          catch_stops do
            increment_dequeue_metric
            check_message_exists
            check_message_is_ready
            find_other_messages_for_batch

            # Process the original message and then all of those
            # found for batching.
            process_message(@queued_message)
            @other_messages&.each { |message| process_message(message) }
          end
        ensure
          @state.finished
        end
        logger.info "finished message unqueue"
      end
    end

    private

    def increment_dequeue_metric
      time_in_queue = Time.now.to_f - @queued_message.created_at.to_f
      log "queue latency is #{time_in_queue}s"
      observe_prometheus_histogram :postal_message_queue_latency,
                                   time_in_queue
    end

    def check_message_exists
      return if @queued_message.message

      log "unqueue because backend message has been removed."
      remove_from_queue
      stop_processing
    end

    def check_message_is_ready
      return if @queued_message.ready?

      log "skipping because message isn't ready for processing"
      @queued_message.unlock
      stop_processing
    end

    def find_other_messages_for_batch
      return unless Postal::Config.postal.batch_queued_messages?

      @other_messages = @queued_message.batchable_messages(Postal::Config.postal.batch_queued_messages_limit)
      log "found #{@other_messages.size} associated messages to process at the same time", batch_key: @queued_message.batch_key
    rescue StandardError
      @queued_message.unlock
      raise
    end

    def process_message(queued_message)
      logger.tagged(queued_message: queued_message.id) do
        SingleMessageProcessor.process(queued_message, logger: @logger, state: @state)
      end
    end

  end
end
