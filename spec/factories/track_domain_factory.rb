# == Schema Information
#
# Table name: track_domains
#
#  id                     :integer          not null, primary key
#  uuid                   :string(255)
#  server_id              :integer
#  domain_id              :integer
#  name                   :string(255)
#  dns_checked_at         :datetime
#  dns_status             :string(255)
#  dns_error              :string(255)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  ssl_enabled            :boolean          default(TRUE)
#  track_clicks           :boolean          default(TRUE)
#  track_loads            :boolean          default(TRUE)
#  excluded_click_domains :text(65535)
#

FactoryBot.define do
  factory :track_domain do
    name { "click" }
    dns_status { "OK" }
    association :server

    after(:build) do |track_domain|
      track_domain.domain ||= create(:domain, owner: track_domain.server)
    end
  end
end
