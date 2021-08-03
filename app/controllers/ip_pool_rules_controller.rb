class IPPoolRulesController < ApplicationController

  include WithinOrganization

  before_action do
    if params[:server_id]
      @server = organization.servers.present.find_by_permalink!(params[:server_id])
      params[:id] && @ip_pool_rule = @server.ip_pool_rules.find_by_uuid!(params[:id])
    else
      params[:id] && @ip_pool_rule = organization.ip_pool_rules.find_by_uuid!(params[:id])
    end
  end

  def index
    if @server
      @ip_pool_rules = @server.ip_pool_rules
    else
      @ip_pool_rules = organization.ip_pool_rules
    end
  end

  def new
    @ip_pool_rule = @server ? @server.ip_pool_rules.build : organization.ip_pool_rules.build
  end

  def create
    scope = @server ? @server.ip_pool_rules : organization.ip_pool_rules
    @ip_pool_rule = scope.build(safe_params)
    if @ip_pool_rule.save
      redirect_to_with_json [organization, @server, :ip_pool_rules]
    else
      render_form_errors "new", @ip_pool_rule
    end
  end

  def update
    if @ip_pool_rule.update(safe_params)
      redirect_to_with_json [organization, @server, :ip_pool_rules]
    else
      render_form_errors "edit", @ip_pool_rule
    end
  end

  def destroy
    @ip_pool_rule.destroy
    redirect_to_with_json [organization, @server, :ip_pool_rules]
  end

  private

  def safe_params
    params.require(:ip_pool_rule).permit(:from_text, :to_text, :ip_pool_id)
  end

end
