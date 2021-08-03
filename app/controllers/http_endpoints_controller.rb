class HTTPEndpointsController < ApplicationController

  include WithinOrganization

  before_action { @server = organization.servers.present.find_by_permalink!(params[:server_id]) }
  before_action { params[:id] && @http_endpoint = @server.http_endpoints.find_by_uuid!(params[:id]) }

  def index
    @http_endpoints = @server.http_endpoints.order(:name).to_a
  end

  def new
    @http_endpoint = @server.http_endpoints.build
  end

  def create
    @http_endpoint = @server.http_endpoints.build(safe_params)
    if @http_endpoint.save
      flash[:notice] = params[:return_notice] if params[:return_notice].present?
      redirect_to_with_json [:return_to, [organization, @server, :http_endpoints]]
    else
      render_form_errors "new", @http_endpoint
    end
  end

  def update
    if @http_endpoint.update(safe_params)
      redirect_to_with_json [organization, @server, :http_endpoints]
    else
      render_form_errors "edit", @http_endpoint
    end
  end

  def destroy
    @http_endpoint.destroy
    redirect_to_with_json [organization, @server, :http_endpoints]
  end

  private

  def safe_params
    params.require(:http_endpoint).permit(:name, :url, :encoding, :format, :strip_replies, :include_attachments, :timeout)
  end

end
