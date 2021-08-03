# == Schema Information
#
# Table name: address_endpoints
#
#  id           :integer          not null, primary key
#  server_id    :integer
#  uuid         :string(255)
#  address      :string(255)
#  last_used_at :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#

class AddressEndpoint < ApplicationRecord

  include HasUUID

  belongs_to :server
  has_many :routes, as: :endpoint
  has_many :additional_route_endpoints, dependent: :destroy, as: :endpoint

  validates :address, presence: true, format: { with: /@/ }, uniqueness: { scope: [:server_id], message: "has already been added" }

  before_destroy :update_routes

  def mark_as_used
    update_column(:last_used_at, Time.now)
  end

  def update_routes
    routes.each { |r| r.update(endpoint: nil, mode: "Reject") }
  end

  def description
    address
  end

  def domain
    address.split("@", 2).last
  end

end
