# == Schema Information
#
# Table name: credentials
#
#  id           :integer          not null, primary key
#  server_id    :integer
#  key          :string(255)
#  type         :string(255)
#  name         :string(255)
#  options      :text(65535)
#  last_used_at :datetime
#  created_at   :datetime
#  updated_at   :datetime
#  hold         :boolean          default(FALSE)
#  uuid         :string(255)
#

class Credential < ApplicationRecord

  include HasUUID

  belongs_to :server

  TYPES = ["SMTP", "API", "SMTP-IP"]

  validates :key, presence: true, uniqueness: true
  validates :type, inclusion: { in: TYPES }
  validates :name, presence: true
  validate :validate_key_cannot_be_changed
  validate :validate_key_for_smtp_ip

  serialize :options, Hash

  before_validation :generate_key

  def generate_key
    return if type == "SMTP-IP"
    return if persisted?

    self.key = SecureRandomString.new(24)
  end

  def to_param
    uuid
  end

  def use
    update_column(:last_used_at, Time.now)
  end

  def usage_type
    if last_used_at.nil?
      "Unused"
    elsif last_used_at < 1.year.ago
      "Inactive"
    elsif last_used_at < 6.months.ago
      "Dormant"
    elsif last_used_at < 1.month.ago
      "Quiet"
    else
      "Active"
    end
  end

  def to_smtp_plain
    Base64.encode64("\0XX\0#{key}").strip
  end

  def ipaddr
    return unless type == "SMTP-IP"

    @ipaddr ||= IPAddr.new(key)
  rescue IPAddr::InvalidAddressError
    nil
  end

  private

  def validate_key_cannot_be_changed
    return if new_record?
    return unless key_changed?
    return if type == "SMTP-IP"

    errors.add :key, "cannot be changed"
  end

  def validate_key_for_smtp_ip
    return unless type == "SMTP-IP"

    IPAddr.new(key.to_s)
  rescue IPAddr::InvalidAddressError
    errors.add :key, "must be a valid IPv4 or IPv6 address"
  end

end
