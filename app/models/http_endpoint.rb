# == Schema Information
#
# Table name: http_endpoints
#
#  id                  :integer          not null, primary key
#  server_id           :integer
#  uuid                :string(255)
#  name                :string(255)
#  url                 :string(255)
#  encoding            :string(255)
#  format              :string(255)
#  strip_replies       :boolean          default(FALSE)
#  error               :text(65535)
#  disabled_until      :datetime
#  last_used_at        :datetime
#  created_at          :datetime
#  updated_at          :datetime
#  include_attachments :boolean          default(TRUE)
#  timeout             :integer
#

class HTTPEndpoint < ApplicationRecord

  DEFAULT_TIMEOUT = 5

  include HasUUID

  belongs_to :server
  has_many :routes, as: :endpoint
  has_many :additional_route_endpoints, dependent: :destroy, as: :endpoint

  ENCODINGS = ["BodyAsJSON", "FormData"]
  FORMATS = ["Hash", "RawMessage"]

  before_destroy :update_routes

  validates :name, presence: true
  validates :url, presence: true
  validates :encoding, inclusion: { in: ENCODINGS }
  validates :format, inclusion: { in: FORMATS }
  validates :timeout, numericality: { greater_than_or_equal_to: 5, less_than_or_equal_to: 60 }

  default_value :timeout, -> { DEFAULT_TIMEOUT }

  def description
    "#{name} (#{url})"
  end

  def mark_as_used
    update_column(:last_used_at, Time.now)
  end

  def update_routes
    routes.each { |r| r.update(endpoint: nil, mode: "Reject") }
  end

end
