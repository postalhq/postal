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

FactoryBot.define do
  factory :user do
    first_name { "John" }
    last_name { "Doe" }
    password { "passw0rd" }
    email_verified_at { Time.now }
    sequence(:email_address) { |n| "user#{n}@example.com" }
  end
end
