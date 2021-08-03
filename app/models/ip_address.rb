# == Schema Information
#
# Table name: ip_addresses
#
#  id         :integer          not null, primary key
#  ip_pool_id :integer
#  ipv4       :string(255)
#  ipv6       :string(255)
#  created_at :datetime
#  updated_at :datetime
#  hostname   :string(255)
#  priority   :integer
#

class IPAddress < ApplicationRecord

  belongs_to :ip_pool

  validates :ipv4, presence: true, uniqueness: true
  validates :hostname, presence: true
  validates :ipv6, uniqueness: { allow_blank: true }
  validates :priority, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, only_integer: true }

  scope :order_by_priority, -> { order(priority: :desc) }

  before_validation :set_default_priority

  private

  def set_default_priority
    return if priority.present?

    self.priority = 100
  end

  class << self

    def select_by_priority
      order(Arel.sql("RAND() * priority DESC")).first
    end

  end

end
