class RoutesController < ApplicationController

  include WithinOrganization

  before_action { @server = organization.servers.present.find_by_permalink!(params[:server_id]) }
  before_action { params[:id] && @route = @server.routes.find_by_uuid!(params[:id]) }

  def index
    @routes = @server.routes.order(:name).includes(:domain, :endpoint).to_a
  end

  def new
    @route = @server.routes.build
  end

  def create
    @route = @server.routes.build(safe_params)
    if @route.save
      redirect_to_with_json [organization, @server, :routes]
    else
      render_form_errors "new", @route
    end
  end

  def update
    if @route.update(safe_params)
      redirect_to_with_json [organization, @server, :routes]
    else
      render_form_errors "edit", @route
    end
  end

  def destroy
    @route.destroy
    redirect_to_with_json [organization, @server, :routes]
  end

  private

  def safe_params
    params.require(:route).permit(:name, :domain_id, :spam_mode, :_endpoint, additional_route_endpoints_array: [])
  end

end
