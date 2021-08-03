# == Schema Information
#
# Table name: smtp_endpoints
#
#  id             :integer          not null, primary key
#  server_id      :integer
#  uuid           :string(255)
#  name           :string(255)
#  hostname       :string(255)
#  ssl_mode       :string(255)
#  port           :integer
#  error          :text(65535)
#  disabled_until :datetime
#  last_used_at   :datetime
#  created_at     :datetime
#  updated_at     :datetime
#

class SMTPEndpoint < ApplicationRecord

  include HasUUID

  belongs_to :server
  has_many :routes, as: :endpoint
  has_many :additional_route_endpoints, dependent: :destroy, as: :endpoint

  SSL_MODES = ["None", "Auto", "STARTTLS", "TLS"]

  before_destroy :update_routes

  validates :name, presence: true
  validates :hostname, presence: true, format: /\A[a-z0-9.\-]*\z/
  validates :ssl_mode, inclusion: { in: SSL_MODES }
  validates :port, numericality: { only_integer: true, allow_blank: true }

  def description
    "#{name} (#{hostname})"
  end

  def mark_as_used
    update_column(:last_used_at, Time.now)
  end

  def update_routes
    routes.each { |r| r.update(endpoint: nil, mode: "Reject") }
  end

end
