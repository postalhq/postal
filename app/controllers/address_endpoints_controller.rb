class AddressEndpointsController < ApplicationController

  include WithinOrganization

  before_action { @server = organization.servers.present.find_by_permalink!(params[:server_id]) }
  before_action { params[:id] && @address_endpoint = @server.address_endpoints.find_by_uuid!(params[:id]) }

  def index
    @address_endpoints = @server.address_endpoints.order(:address).to_a
  end

  def new
    @address_endpoint = @server.address_endpoints.build
  end

  def create
    @address_endpoint = @server.address_endpoints.build(safe_params)
    if @address_endpoint.save
      flash[:notice] = params[:return_notice] if params[:return_notice].present?
      redirect_to_with_json [:return_to, [organization, @server, :address_endpoints]]
    else
      render_form_errors "new", @address_endpoint
    end
  end

  def update
    if @address_endpoint.update(safe_params)
      redirect_to_with_json [organization, @server, :address_endpoints]
    else
      render_form_errors "edit", @address_endpoint
    end
  end

  def destroy
    @address_endpoint.destroy
    redirect_to_with_json [organization, @server, :address_endpoints]
  end

  private

  def safe_params
    params.require(:address_endpoint).permit(:address)
  end

end
