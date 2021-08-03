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

require "resolv"

class TrackDomain < ApplicationRecord

  include HasUUID

  belongs_to :server
  belongs_to :domain

  validates :name, presence: true, format: { with: /\A[a-z0-9\-]+\z/ }, uniqueness: { scope: :domain_id, message: "is already added" }
  validates :domain_id, uniqueness: { scope: :server_id, message: "already has a track domain for this server" }
  validate :validate_domain_belongs_to_server

  scope :ok, -> { where(dns_status: "OK") }

  after_create :check_dns, unless: :dns_status

  before_validation do
    self.server = domain.server if domain && server.nil?
  end

  def full_name
    "#{name}.#{domain.name}"
  end

  def excluded_click_domains_array
    @excluded_click_domains_array ||= excluded_click_domains ? excluded_click_domains.split("\n").map(&:strip) : []
  end

  def dns_ok?
    dns_status == "OK"
  end

  def check_dns
    result = domain.resolver.getresources(full_name, Resolv::DNS::Resource::IN::CNAME)
    records = result.map { |r| r.name.to_s.downcase }
    if records.empty?
      self.dns_status = "Missing"
      self.dns_error = "There is no record at #{full_name}"
    else
      if records.size == 1 && records.first == Postal.config.dns.track_domain
        self.dns_status = "OK"
        self.dns_error = nil
      else
        self.dns_status = "Invalid"
        self.dns_error = "There is a CNAME record at #{full_name} but it points to #{records.first} which is incorrect. It should point to #{Postal.config.dns.track_domain}."
      end
    end
    self.dns_checked_at = Time.now
    save!
    dns_ok?
  end

  def use_ssl?
    ssl_enabled?
  end

  def validate_domain_belongs_to_server
    if domain && ![server, server.organization].include?(domain.owner)
      errors.add :domain, "does not belong to the server or the server's organization"
    end
  end

end
