# frozen_string_literal: true

module Worker
  # The Postal Worker process is responsible for handling all background tasks. This includes processing of all
  # messages, webhooks and other administrative tasks. There are two main types of background work which is completed,
  # jobs and scheduled tasks.
  #
  # The 'Jobs' here allow for the continuous monitoring of a database table (or queue) and processing of any new items
  # which may appear in that. The polling takes place every 5 seconds by default and the work is able to run multiple
  # threads to look for and process this work.
  #
  # Scheduled Tasks allow for code to be executed on a ROUGH schedule. This is used for administrative tasks.  A single
  # thread will run within each worker process and attempt to acquire the 'tasks' role. If successful it will run all
  # tasks which are due to be run. The tasks are then scheduled to run again at a future time. Workers which are not
  # successful in acquiring the role will not run any tasks but will still attempt to acquire a lock in case the current
  # acquiree disappears.
  #
  # The worker process will run until it receives a TERM or INT signal. It will then attempt to gracefully shut down
  # after it has completed any outstanding jobs which are already inflight.
  class Process

    include HasPrometheusMetrics

    # An array of job classes that should be processed each time the worker ticks.
    #
    # @return [Array<Class>]
    JOBS = [
      Jobs::ProcessQueuedMessagesJob,
      Jobs::ProcessWebhookRequestsJob,
    ].freeze

    # An array of tasks that should be processed
    #
    # @return [Array<Class>]
    TASKS = [
      ActionDeletionsScheduledTask,
      CheckAllDNSScheduledTask,
      CleanupAuthieSessionsScheduledTask,
      ExpireHeldMessagesScheduledTask,
      ProcessMessageRetentionScheduledTask,
      PruneSuppressionListsScheduledTask,
      PruneWebhookRequestsScheduledTask,
      SendNotificationsScheduledTask,
      TidyQueuedMessagesTask,
    ].freeze

    # @param [Integer] thread_count The number of worker threads to run in this process
    def initialize(thread_count: Postal::Config.worker.threads,
                   work_sleep_time: 5,
                   task_sleep_time: 60)
      @thread_count = thread_count
      @exit_pipe_read, @exit_pipe_write = IO.pipe
      @work_sleep_time = work_sleep_time
      @task_sleep_time = task_sleep_time
      @threads = []

      setup_prometheus
    end

    def run
      logger.tagged(component: "worker") do
        setup_traps
        ensure_connection_pool_size_is_suitable
        start_work_threads
        start_tasks_thread
        wait_for_threads
      end
    end

    private

    # Install signal traps to allow for graceful shutdown
    #
    # @return [void]
    def setup_traps
      trap("INT") { receive_signal("INT") }
      trap("TERM") { receive_signal("TERM") }
    end

    # Receive a signal and set the shutdown flag
    #
    # @param [String] signal The signal that was received z
    # @return [void]
    def receive_signal(signal)
      puts "Received #{signal} signal. Stopping when able."
      @shutdown = true
      @exit_pipe_write.close
    end

    # Wait for the period of time and return true or false if shutdown has been requested. If the shutdown is
    # requested during the wait, it will return immediately otherwise it will return false when it has finished
    # waiting for the period of time.
    #
    # @param [Integer] wait_time The time to wait for
    # @return [Boolean]
    def shutdown_after_wait?(wait_time)
      @exit_pipe_read.wait_readable(wait_time) ? true : false
    end

    # Ensure that the connection pool is big enough for the number of threads
    # configured.
    #
    # @return [void]
    def ensure_connection_pool_size_is_suitable
      current_pool_size = ActiveRecord::Base.connection_pool.size
      desired_pool_size = @thread_count + 3

      return if current_pool_size >= desired_pool_size

      logger.warn "number of worker threads (#{@thread_count}) is more  " \
                  "than the db connection pool size (#{current_pool_size}+3), " \
                  "increasing connection pool size to #{desired_pool_size}"

      Postal.change_database_connection_pool_size(desired_pool_size)
    end

    # Wait for all threads to complete
    #
    # @return [void]
    def wait_for_threads
      @threads.each(&:join)
    end

    # Start the worker threads
    #
    # @return [void]
    def start_work_threads
      logger.info "starting #{@thread_count} work threads"
      @thread_count.times do |index|
        start_work_thread(index)
      end
    end

    # Start a worker thread
    #
    # @return [void]
    def start_work_thread(index)
      @threads << Thread.new do
        logger.tagged(component: "worker", thread: "work#{index}") do
          logger.info "started work thread #{index}"
          loop do
            work_completed = work(index)

            if shutdown_after_wait?(work_completed ? 0 : @work_sleep_time)
              break
            end
          end

          logger.info "stopping work thread #{index}"
        end
      end
    end

    # Actually perform the work for this tick. This will call each job which has been registered.
    #
    # @return [Boolean] Whether any work was completed in this job or not
    def work(thread)
      completed_work = 0
      ActiveRecord::Base.connection_pool.with_connection do
        JOBS.each do |job_class|
          capture_errors do
            job = job_class.new(logger: logger)

            time = Benchmark.realtime { job.call }

            observe_prometheus_histogram :postal_worker_job_runtime,
                                         time,
                                         labels: {
                                          thread: thread,
                                          job: job_class.to_s.split("::").last
                                         }

            if job.work_completed?
              completed_work += 1
              increment_prometheus_counter :postal_worker_job_executions,
                                           labels: {
                                              thread: thread,
                                              job: job_class.to_s.split("::").last
                                           }
            end
          end
        end
      end
      completed_work.positive?
    end

    # Start the tasks thread
    #
    # @return [void]
    def start_tasks_thread
      logger.info "starting tasks thread"
      @threads << Thread.new do
        logger.tagged(component: "worker", thread: "tasks") do
          loop do
            run_tasks

            if shutdown_after_wait?(@task_sleep_time)
              break
            end
          end

          logger.info "stopping tasks thread"
          ActiveRecord::Base.connection_pool.with_connection do
            if WorkerRole.release(:tasks)
              logger.info "released tasks role"
            end
          end
        end
      end
    end

    # Run the tasks. This will attempt to acquire the tasks role and if successful it will all the registered
    # tasks if they are due to be run.
    #
    # @return [void]
    def run_tasks
      role_acquisition_status = ActiveRecord::Base.connection_pool.with_connection do
        WorkerRole.acquire(:tasks)
      end

      case role_acquisition_status
      when :stolen
        logger.info "acquired task role by stealing it from a lazy worker"
      when :created
        logger.info "acquired task role by creating it"
      when :renewed
        logger.debug "acquired task role by renewing it"
      else
        logger.debug "could not acquire task role, not doing anything"
        return false
      end

      ActiveRecord::Base.connection_pool.with_connection do
        TASKS.each { |task| run_task(task) }
      end
    end

    # Run a single task
    #
    # @param [Class] task The task to run
    # @return [void]
    def run_task(task)
      logger.tagged task: task do
        scheduled_task = ScheduledTask.find_by(name: task.to_s)
        if scheduled_task.nil?
          logger.info "no existing task object, creating it now"
          scheduled_task = ScheduledTask.create!(name: task.to_s, next_run_after: task.next_run_after)
        end

        next unless scheduled_task.next_run_after < Time.current

        logger.info "running task"

        time = 0
        capture_errors do
          time = Benchmark.realtime do
            task.new(logger: logger).call
          end

          observe_prometheus_histogram :postal_worker_task_runtime,
                                       time,
                                       labels: {
                                        task: task.to_s.split("::").last
                                       }
        end

        next_run_after = task.next_run_after
        logger.info "scheduling task to next run at #{next_run_after}"
        scheduled_task.update!(next_run_after: next_run_after)
      end
    end

    # Return the logger
    #
    # @return [Klogger::Logger]
    def logger
      Postal.logger
    end

    # Capture exceptions and handle this as appropriate.
    #
    # @yield The block of code to run
    # @return [void]
    def capture_errors
      yield
    rescue StandardError => e
      logger.error "#{e.class} (#{e.message})"
      e.backtrace.each { |line| logger.error line }
      Sentry.capture_exception(e) if defined?(Sentry)

      increment_prometheus_counter :postal_worker_errors,
                                   labels: { error: e.class.to_s }
    end

    def setup_prometheus
      register_prometheus_counter :postal_worker_job_executions,
                                  docstring: "The number of jobs worked by a worker where work was completed",
                                  labels: [:thread, :job]

      register_prometheus_histogram :postal_worker_job_runtime,
                                    docstring: "The time taken to process jobs",
                                    labels: [:thread, :job]

      register_prometheus_counter :postal_worker_errors,
                                  docstring: "The number of errors encountered while processing jobs",
                                  labels: [:error]

      register_prometheus_histogram :postal_worker_task_runtime,
                                    docstring: "The time taken to process tasks",
                                    labels: [:task]

      register_prometheus_histogram :postal_message_queue_latency,
                                    docstring: "The length of time between a message being queued and being dequeued"
    end

  end
end
