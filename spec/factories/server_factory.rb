# == Schema Information
#
# Table name: servers
#
#  id                                 :integer          not null, primary key
#  organization_id                    :integer
#  uuid                               :string(255)
#  name                               :string(255)
#  mode                               :string(255)
#  ip_pool_id                         :integer
#  created_at                         :datetime
#  updated_at                         :datetime
#  permalink                          :string(255)
#  send_limit                         :integer
#  deleted_at                         :datetime
#  message_retention_days             :integer
#  raw_message_retention_days         :integer
#  raw_message_retention_size         :integer
#  allow_sender                       :boolean          default(FALSE)
#  token                              :string(255)
#  send_limit_approaching_at          :datetime
#  send_limit_approaching_notified_at :datetime
#  send_limit_exceeded_at             :datetime
#  send_limit_exceeded_notified_at    :datetime
#  spam_threshold                     :decimal(8, 2)
#  spam_failure_threshold             :decimal(8, 2)
#  postmaster_address                 :string(255)
#  suspended_at                       :datetime
#  outbound_spam_threshold            :decimal(8, 2)
#  domains_not_to_click_track         :text(65535)
#  suspension_reason                  :string(255)
#  log_smtp_data                      :boolean          default(FALSE)
#
# Indexes
#
#  index_servers_on_organization_id  (organization_id)
#  index_servers_on_permalink        (permalink)
#  index_servers_on_token            (token)
#  index_servers_on_uuid             (uuid)
#

FactoryBot.define do
  factory :server do
    association :organization
    name { "Mail Server" }
    mode { "Live" }
    provision_database { false }
    sequence(:permalink) { |n| "server#{n}" }
  end
end
