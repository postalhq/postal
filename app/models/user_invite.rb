# == Schema Information
#
# Table name: user_invites
#
#  id            :integer          not null, primary key
#  uuid          :string(255)
#  email_address :string(255)
#  expires_at    :datetime
#  created_at    :datetime
#  updated_at    :datetime
#
# Indexes
#
#  index_user_invites_on_uuid  (uuid)
#

class UserInvite < ApplicationRecord

  include HasUUID

  validates :email_address, presence: true, uniqueness: true, format: { with: /@/, allow_blank: true }

  has_many :organization_users, dependent: :destroy, as: :user
  has_many :organizations, through: :organization_users

  default_value :expires_at, -> { 7.days.from_now }

  scope :active, -> { where("expires_at > ?", Time.now) }

  def md5_for_gravatar
    @md5_for_gravatar ||= Digest::MD5.hexdigest(email_address.to_s.downcase)
  end

  def avatar_url
    @avatar_url ||= email_address ? "https://secure.gravatar.com/avatar/#{md5_for_gravatar}?rating=PG&size=120&d=mm" : nil
  end

  def name
    email_address
  end

  def accept(user)
    transaction do
      organization_users.each do |ou|
        ou.update(user: user) || ou.destroy
      end
      organization_users.reload
      destroy
    end
  end

  def reject
    destroy
  end

end
