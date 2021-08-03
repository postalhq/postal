# == Schema Information
#
# Table name: users
#
#  id                               :integer          not null, primary key
#  uuid                             :string(255)
#  first_name                       :string(255)
#  last_name                        :string(255)
#  email_address                    :string(255)
#  password_digest                  :string(255)
#  time_zone                        :string(255)
#  email_verification_token         :string(255)
#  email_verified_at                :datetime
#  created_at                       :datetime
#  updated_at                       :datetime
#  password_reset_token             :string(255)
#  password_reset_token_valid_until :datetime
#  admin                            :boolean          default(FALSE)
#
# Indexes
#
#  index_users_on_email_address  (email_address)
#  index_users_on_uuid           (uuid)
#

class User < ApplicationRecord

  include HasUUID

  require_dependency "user/authentication"

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email_address, presence: true, uniqueness: true, format: { with: /@/, allow_blank: true }
  validates :time_zone, presence: true

  default_value :time_zone, -> { "UTC" }

  has_many :organization_users, dependent: :destroy, as: :user
  has_many :organizations, through: :organization_users

  def organizations_scope
    @organizations_scope ||= begin
      if admin?
        Organization.present
      else
        organizations.present
      end
    end
  end

  def name
    "#{first_name} #{last_name}"
  end

  def to_param
    uuid
  end

  def md5_for_gravatar
    @md5_for_gravatar ||= Digest::MD5.hexdigest(email_address.to_s.downcase)
  end

  def avatar_url
    @avatar_url ||= email_address ? "https://secure.gravatar.com/avatar/#{md5_for_gravatar}?rating=PG&size=120&d=mm" : nil
  end

  def email_tag
    "#{name} <#{email_address}>"
  end

  def self.[](email)
    where(email_address: email).first
  end

end
