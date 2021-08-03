# == Schema Information
#
# Table name: webhooks
#
#  id           :integer          not null, primary key
#  server_id    :integer
#  uuid         :string(255)
#  name         :string(255)
#  url          :string(255)
#  last_used_at :datetime
#  all_events   :boolean          default(FALSE)
#  enabled      :boolean          default(TRUE)
#  sign         :boolean          default(TRUE)
#  created_at   :datetime
#  updated_at   :datetime
#
# Indexes
#
#  index_webhooks_on_server_id  (server_id)
#

class Webhook < ApplicationRecord

  include HasUUID

  belongs_to :server
  has_many :webhook_events, dependent: :destroy
  has_many :webhook_requests

  validates :name, presence: true
  validates :url, presence: true, format: { with: /\Ahttps?:\/\/[a-z0-9\-._?=&\/+:]+\z/i, allow_blank: true }

  scope :enabled, -> { where(enabled: true) }

  after_save :save_events

  when_attribute :all_events, changes_to: true do
    after_save do
      webhook_events.destroy_all
    end
  end

  def events
    @events ||= webhook_events.map(&:event)
  end

  def events=(value)
    @events = value.map(&:to_s).select(&:present?)
  end

  def save_events
    if @events
      @events.each do |event|
        webhook_events.where(event: event).first_or_create!
      end
      webhook_events.where.not(event: @events).destroy_all
    end
  end

end
