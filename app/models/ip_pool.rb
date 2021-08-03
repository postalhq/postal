# == Schema Information
#
# Table name: ip_pools
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  uuid       :string(255)
#  created_at :datetime
#  updated_at :datetime
#  default    :boolean          default(FALSE)
#
# Indexes
#
#  index_ip_pools_on_uuid  (uuid)
#

class IPPool < ApplicationRecord

  include HasUUID

  validates :name, presence: true

  has_many :ip_addresses, dependent: :restrict_with_exception
  has_many :servers, dependent: :restrict_with_exception
  has_many :organization_ip_pools, dependent: :destroy
  has_many :organizations, through: :organization_ip_pools
  has_many :ip_pool_rules, dependent: :destroy

  def self.default
    where(default: true).order(:id).first
  end

end
