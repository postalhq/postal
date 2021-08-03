# == Schema Information
#
# Table name: queued_messages
#
#  id            :integer          not null, primary key
#  server_id     :integer
#  message_id    :integer
#  domain        :string(255)
#  locked_by     :string(255)
#  locked_at     :datetime
#  retry_after   :datetime
#  created_at    :datetime
#  updated_at    :datetime
#  ip_address_id :integer
#  attempts      :integer          default(0)
#  route_id      :integer
#  manual        :boolean          default(FALSE)
#  batch_key     :string(255)
#
# Indexes
#
#  index_queued_messages_on_domain      (domain)
#  index_queued_messages_on_message_id  (message_id)
#  index_queued_messages_on_server_id   (server_id)
#

class QueuedMessage < ApplicationRecord

  include HasMessage

  belongs_to :server
  belongs_to :ip_address, optional: true
  belongs_to :user, optional: true

  before_create :allocate_ip_address
  after_commit :queue, on: :create

  scope :unlocked, -> { where(locked_at: nil) }
  scope :retriable, -> { where("retry_after IS NULL OR retry_after <= ?", 30.seconds.from_now) }

  def retriable?
    retry_after.nil? || retry_after <= 30.seconds.from_now
  end

  def queue
    UnqueueMessageJob.queue(queue_name, id: id)
  end

  def queue!
    update_column(:retry_after, nil)
    queue
  end

  def queue_name
    ip_address ? :"outgoing-#{ip_address.id}" : :main
  end

  def send_bounce
    if message.send_bounces?
      Postal::BounceMessage.new(server, message).queue
    end
  end

  def allocate_ip_address
    if Postal.ip_pools? && message && pool = server.ip_pool_for_message(message)
      self.ip_address = pool.ip_addresses.select_by_priority
    end
  end

  def acquire_lock
    time = Time.now
    locker = Postal.locker_name
    rows = self.class.where(id: id, locked_by: nil, locked_at: nil).update_all(locked_by: locker, locked_at: time)
    if rows == 1
      self.locked_by = locker
      self.locked_at = time
      true
    else
      false
    end
  end

  def retry_later(time = nil)
    retry_time = time || self.class.calculate_retry_time(attempts, 5.minutes)
    self.locked_by = nil
    self.locked_at = nil
    update_columns(locked_by: nil, locked_at: nil, retry_after: Time.now + retry_time, attempts: attempts + 1)
  end

  def unlock
    self.locked_by = nil
    self.locked_at = nil
    update_columns(locked_by: nil, locked_at: nil)
  end

  def self.calculate_retry_time(attempts, initial_period)
    (1.3**attempts) * initial_period
  end

  def locked?
    locked_at.present?
  end

  def batchable_messages(limit = 10)
    unless locked?
      raise Postal::Error, "Must lock current message before locking any friends"
    end

    if batch_key.nil?
      []
    else
      time = Time.now
      locker = Postal.locker_name
      self.class.retriable.where(batch_key: batch_key, ip_address_id: ip_address_id, locked_by: nil, locked_at: nil).limit(limit).update_all(locked_by: locker, locked_at: time)
      QueuedMessage.where(batch_key: batch_key, ip_address_id: ip_address_id, locked_by: locker, locked_at: time).where.not(id: id)
    end
  end

  def self.requeue_all
    unlocked.retriable.each(&:queue)
  end

end
