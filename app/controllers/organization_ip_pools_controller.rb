class OrganizationIPPoolsController < ApplicationController

  include WithinOrganization
  before_action :admin_required, only: [:assignments]

  def index
    @ip_pools = organization.ip_pools.order(:name)
  end

  def assignments
    organization.ip_pool_ids = params[:ip_pools]
    organization.save!
    redirect_to [organization, :ip_pools], notice: "Organization IP pools have been updated successfully"
  end

end
