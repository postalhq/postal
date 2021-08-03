# == Schema Information
#
# Table name: domains
#
#  id                     :integer          not null, primary key
#  server_id              :integer
#  uuid                   :string(255)
#  name                   :string(255)
#  verification_token     :string(255)
#  verification_method    :string(255)
#  verified_at            :datetime
#  dkim_private_key       :text(65535)
#  created_at             :datetime
#  updated_at             :datetime
#  dns_checked_at         :datetime
#  spf_status             :string(255)
#  spf_error              :string(255)
#  dkim_status            :string(255)
#  dkim_error             :string(255)
#  mx_status              :string(255)
#  mx_error               :string(255)
#  return_path_status     :string(255)
#  return_path_error      :string(255)
#  outgoing               :boolean          default(TRUE)
#  incoming               :boolean          default(TRUE)
#  owner_type             :string(255)
#  owner_id               :integer
#  dkim_identifier_string :string(255)
#  use_for_any            :boolean
#
# Indexes
#
#  index_domains_on_server_id  (server_id)
#  index_domains_on_uuid       (uuid)
#

FactoryBot.define do
  factory :domain do
    association :owner, factory: :user
    sequence(:name) { |n| "example#{n}.com" }
    verification_method { "DNS" }
    verified_at { Time.now }
  end

  factory :organization_domain, parent: :domain do
    association :owner, factory: :organization
  end
end
