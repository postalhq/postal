class IPAddressesController < ApplicationController

  before_action :admin_required
  before_action { @ip_pool = IPPool.find_by_uuid!(params[:ip_pool_id]) }
  before_action { params[:id] && @ip_address = @ip_pool.ip_addresses.find(params[:id]) }

  def new
    @ip_address = @ip_pool.ip_addresses.build
  end

  def create
    @ip_address = @ip_pool.ip_addresses.build(safe_params)
    if @ip_address.save
      redirect_to_with_json [:edit, @ip_pool]
    else
      render_form_errors "new", @ip_address
    end
  end

  def update
    if @ip_address.update(safe_params)
      redirect_to_with_json [:edit, @ip_pool]
    else
      render_form_errors "edit", @ip_address
    end
  end

  def destroy
    @ip_address.destroy
    redirect_to_with_json [:edit, @ip_pool]
  end

  private

  def safe_params
    params.require(:ip_address).permit(:ipv4, :ipv6, :hostname, :priority)
  end

end
