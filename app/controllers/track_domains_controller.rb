class TrackDomainsController < ApplicationController

  include WithinOrganization
  before_action { @server = organization.servers.present.find_by_permalink!(params[:server_id]) }
  before_action { params[:id] && @track_domain = @server.track_domains.find_by_uuid!(params[:id]) }

  def index
    @track_domains = @server.track_domains.order(:name).to_a
  end

  def new
    @track_domain = @server.track_domains.build
  end

  def create
    @track_domain = @server.track_domains.build(params.require(:track_domain).permit(:name, :domain_id, :track_loads, :track_clicks, :excluded_click_domains, :ssl_enabled))
    if @track_domain.save
      redirect_to_with_json [:return_to, [organization, @server, :track_domains]]
    else
      render_form_errors "new", @track_domain
    end
  end

  def update
    if @track_domain.update(params.require(:track_domain).permit(:track_loads, :track_clicks, :excluded_click_domains, :ssl_enabled))
      redirect_to_with_json [organization, @server, :track_domains]
    else
      render_form_errors "edit", @track_domain
    end
  end

  def destroy
    @track_domain.destroy
    redirect_to_with_json [organization, @server, :track_domains]
  end

  def check
    if @track_domain.check_dns
      redirect_to_with_json [organization, @server, :track_domains], notice: "Your CNAME for #{@track_domain.full_name} looks good!"
    else
      redirect_to_with_json [organization, @server, :track_domains], alert: "There seems to be something wrong with your DNS record. Check documentation for information."
    end
  end

  def toggle_ssl
    @track_domain.update(ssl_enabled: !@track_domain.ssl_enabled)
    redirect_to_with_json [organization, @server, :track_domains], notice: "SSL settings for #{@track_domain.full_name} updated successfully."
  end

end
