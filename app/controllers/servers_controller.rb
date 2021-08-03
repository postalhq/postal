class ServersController < ApplicationController

  include WithinOrganization

  before_action :admin_required, only: [:advanced, :suspend, :unsuspend]
  before_action { params[:id] && @server = organization.servers.present.find_by_permalink!(params[:id]) }

  def index
    @servers = organization.servers.present.order(:name).to_a
  end

  def show
    if @server.created_at < 48.hours.ago
      @graph_type = :daily
      graph_data = @server.message_db.statistics.get(:daily, [:incoming, :outgoing, :bounces], Time.now, 30)
    elsif @server.created_at < 24.hours.ago
      @graph_type = :hourly
      graph_data = @server.message_db.statistics.get(:hourly, [:incoming, :outgoing, :bounces], Time.now, 48)
    else
      @graph_type = :hourly
      graph_data = @server.message_db.statistics.get(:hourly, [:incoming, :outgoing, :bounces], Time.now, 24)
    end
    @first_date = graph_data.first.first
    @last_date = graph_data.last.first
    @graph_data = graph_data.map(&:last)
    @messages = @server.message_db.messages(order: "id", direction: "desc", limit: 6)
  end

  def new
    @server = organization.servers.build
  end

  def create
    @server = organization.servers.build(safe_params(:permalink))
    if @server.save
      redirect_to_with_json organization_server_path(organization, @server)
    else
      render_form_errors "new", @server
    end
  end

  def update
    extra_params = [:spam_threshold, :spam_failure_threshold, :postmaster_address]
    extra_params += [:send_limit, :allow_sender, :log_smtp_data, :outbound_spam_threshold, :message_retention_days, :raw_message_retention_days, :raw_message_retention_size] if current_user.admin?
    if @server.update(safe_params(*extra_params))
      redirect_to_with_json organization_server_path(organization, @server), notice: "Server settings have been updated"
    else
      render_form_errors "edit", @server
    end
  end

  def destroy
    unless current_user.authenticate(params[:password])
      respond_to do |wants|
        wants.html do
          redirect_to [:delete, organization, @server], alert: "The password you entered was not valid. Please check and try again."
        end
        wants.json do
          render json: { alert: "The password you entere was invalid. Please check and try again" }
        end
      end
      return
    end
    @server.soft_destroy
    redirect_to_with_json organization_root_path(organization), notice: "#{@server.name} has been deleted successfully"
  end

  def queue
    @messages = @server.queued_messages.order(id: :desc).page(params[:page])
    @messages_with_message = @messages.include_message
  end

  def suspend
    @server.suspend(params[:reason])
    redirect_to_with_json [organization, @server], notice: "Server has been suspended"
  end

  def unsuspend
    @server.unsuspend
    redirect_to_with_json [organization, @server], notice: "Server has been unsuspended"
  end

  private

  def safe_params(*extras)
    params.require(:server).permit(:name, :mode, :ip_pool_id, *extras)
  end

end
