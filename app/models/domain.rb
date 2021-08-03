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

require "resolv"

class Domain < ApplicationRecord

  include HasUUID

  require_dependency "domain/dns_checks"
  require_dependency "domain/dns_verification"

  VERIFICATION_EMAIL_ALIASES = ["webmaster", "postmaster", "admin", "administrator", "hostmaster"]

  belongs_to :server, optional: true
  belongs_to :owner, optional: true, polymorphic: true
  has_many :routes, dependent: :destroy
  has_many :track_domains, dependent: :destroy

  VERIFICATION_METHODS = ["DNS", "Email"]

  validates :name, presence: true, format: { with: /\A[a-z0-9\-.]*\z/ }, uniqueness: { scope: [:owner_type, :owner_id], message: "is already added" }
  validates :verification_method, inclusion: { in: VERIFICATION_METHODS }

  random_string :dkim_identifier_string, type: :chars, length: 6, unique: true, upper_letters_only: true

  before_create :generate_dkim_key

  scope :verified, -> { where.not(verified_at: nil) }

  when_attribute :verification_method, changes_to: :anything do
    before_save do
      if verification_method == "DNS"
        self.verification_token = Nifty::Utils::RandomString.generate(length: 32)
      elsif verification_method == "Email"
        self.verification_token = rand(999_999).to_s.ljust(6, "0")
      else
        self.verification_token = nil
      end
    end
  end

  def verified?
    verified_at.present?
  end

  def verify
    self.verified_at = Time.now
    save!
  end

  def parent_domains
    parts = name.split(".")
    parts[0, parts.size - 1].each_with_index.map do |_, i|
      parts[i..-1].join(".")
    end
  end

  def generate_dkim_key
    self.dkim_private_key = OpenSSL::PKey::RSA.new(1024).to_s
  end

  def dkim_key
    @dkim_key ||= OpenSSL::PKey::RSA.new(dkim_private_key)
  end

  def to_param
    uuid
  end

  def verification_email_addresses
    parent_domains.map do |domain|
      VERIFICATION_EMAIL_ALIASES.map do |a|
        "#{a}@#{domain}"
      end
    end.flatten
  end

  def spf_record
    "v=spf1 a mx include:#{Postal.config.dns.spf_include} ~all"
  end

  def dkim_record
    public_key = dkim_key.public_key.to_s.gsub(/-+[A-Z ]+-+\n/, "").gsub(/\n/, "")
    "v=DKIM1; t=s; h=sha256; p=#{public_key};"
  end

  def dkim_identifier
    Postal.config.dns.dkim_identifier + "-#{dkim_identifier_string}"
  end

  def dkim_record_name
    "#{dkim_identifier}._domainkey"
  end

  def return_path_domain
    "#{Postal.config.dns.custom_return_path_prefix}.#{name}"
  end

  def nameservers
    @nameservers ||= get_nameservers
  end

  def resolver
    @resolver ||= Postal.config.general.use_local_ns_for_domains? ? Resolv::DNS.new : Resolv::DNS.new(nameserver: nameservers)
  end

  private

  def get_nameservers
    local_resolver = Resolv::DNS.new
    ns_records = []
    parts = name.split(".")
    (parts.size - 1).times do |n|
      d = parts[n, parts.size - n + 1].join(".")
      ns_records = local_resolver.getresources(d, Resolv::DNS::Resource::IN::NS).map { |s| s.name.to_s }
      break unless ns_records.blank?
    end
    return [] if ns_records.blank?

    ns_records = ns_records.map { |r| local_resolver.getresources(r, Resolv::DNS::Resource::IN::A).map { |s| s.address.to_s } }.flatten
    return [] if ns_records.blank?

    ns_records
  end

end
