# == Schema Information
#
# Table name: organizations
#
#  id                :integer          not null, primary key
#  uuid              :string(255)
#  name              :string(255)
#  permalink         :string(255)
#  time_zone         :string(255)
#  created_at        :datetime
#  updated_at        :datetime
#  ip_pool_id        :integer
#  owner_id          :integer
#  deleted_at        :datetime
#  suspended_at      :datetime
#  suspension_reason :string(255)
#
# Indexes
#
#  index_organizations_on_permalink  (permalink)
#  index_organizations_on_uuid       (uuid)
#

class Organization < ApplicationRecord

  RESERVED_PERMALINKS = ["new", "edit", "remove", "delete", "destroy", "admin", "mail", "org", "server"]

  INITIAL_QUOTA = 10
  INITIAL_SUPER_QUOTA = 10_000
  include HasUUID
  include HasSoftDestroy

  validates :name, presence: true
  validates :permalink, presence: true, format: { with: /\A[a-z0-9\-]*\z/ }, uniqueness: true, exclusion: { in: RESERVED_PERMALINKS }
  validates :time_zone, presence: true

  default_value :time_zone, -> { "UTC" }
  default_value :permalink, -> { Organization.find_unique_permalink(name) if name }

  belongs_to :owner, class_name: "User"
  has_many :organization_users, dependent: :destroy
  has_many :users, through: :organization_users, source_type: "User"
  has_many :user_invites, through: :organization_users, source_type: "UserInvite", source: :user
  has_many :servers, dependent: :destroy
  has_many :domains, as: :owner, dependent: :destroy
  has_many :organization_ip_pools, dependent: :destroy
  has_many :ip_pools, through: :organization_ip_pools
  has_many :ip_pool_rules, dependent: :destroy, as: :owner

  after_create do
    if pool = IPPool.default
      ip_pools << IPPool.default
    end
  end

  def status
    if suspended?
      "Suspended"
    else
      "Active"
    end
  end

  def to_param
    permalink
  end

  def suspended?
    suspended_at.present?
  end

  def user_assignment(user)
    @user_assignments ||= {}
    @user_assignments[user.id] ||= organization_users.where(user: user).first
  end

  def make_owner(new_owner)
    user_assignment(new_owner).update(admin: true, all_servers: true)
    update(owner: new_owner)
  end

  # This is an array of addresses that should receive notifications for this organization
  def notification_addresses
    users.map(&:email_tag)
  end

  def self.find_unique_permalink(name)
    loop.each_with_index do |_, i|
      i = i + 1
      proposal = name.parameterize
      proposal += "-#{i}" if i > 1
      unless where(permalink: proposal).exists?
        return proposal
      end
    end
  end

  def self.[](id)
    if id.is_a?(String)
      where(permalink: id).first
    else
      where(id: id.to_i).first
    end
  end

end
