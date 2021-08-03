class WebhooksController < ApplicationController

  include WithinOrganization
  before_action { @server = organization.servers.present.find_by_permalink!(params[:server_id]) }
  before_action { params[:id] && @webhook = @server.webhooks.find_by_uuid!(params[:id]) }

  def index
    @webhooks = @server.webhooks.order(:url).to_a
  end

  def new
    @webhook = @server.webhooks.build(all_events: true)
  end

  def create
    @webhook = @server.webhooks.build(safe_params)
    if @webhook.save
      redirect_to_with_json [organization, @server, :webhooks]
    else
      render_form_errors "new", @webhook
    end
  end

  def update
    if @webhook.update(safe_params)
      redirect_to_with_json [organization, @server, :webhooks]
    else
      render_form_errors "edit", @webhook
    end
  end

  def destroy
    @webhook.destroy
    redirect_to_with_json [organization, @server, :webhooks]
  end

  def history
    @current_page = params[:page] ? params[:page].to_i : 1
    @requests = @server.message_db.webhooks.list(@current_page)
  end

  def history_request
    @req = @server.message_db.webhooks.find(params[:uuid])
  end

  private

  def safe_params
    params.require(:webhook).permit(:name, :url, :all_events, :enabled, events: [])
  end

end
