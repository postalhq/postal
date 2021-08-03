class SMTPEndpointsController < ApplicationController

  include WithinOrganization
  before_action { @server = organization.servers.present.find_by_permalink!(params[:server_id]) }
  before_action { params[:id] && @smtp_endpoint = @server.smtp_endpoints.find_by_uuid!(params[:id]) }

  def index
    @smtp_endpoints = @server.smtp_endpoints.order(:name).to_a
  end

  def new
    @smtp_endpoint = @server.smtp_endpoints.build
  end

  def create
    @smtp_endpoint = @server.smtp_endpoints.build(safe_params)
    if @smtp_endpoint.save
      flash[:notice] = params[:return_notice] if params[:return_notice].present?
      redirect_to_with_json [:return_to, [organization, @server, :smtp_endpoints]]
    else
      render_form_errors "new", @smtp_endpoint
    end
  end

  def update
    if @smtp_endpoint.update(safe_params)
      redirect_to_with_json [organization, @server, :smtp_endpoints]
    else
      render_form_errors "edit", @smtp_endpoint
    end
  end

  def destroy
    @smtp_endpoint.destroy
    redirect_to_with_json [organization, @server, :smtp_endpoints]
  end

  private

  def safe_params
    params.require(:smtp_endpoint).permit(:name, :hostname, :port, :ssl_mode)
  end

end
