class OrganizationsController < ApplicationController

  before_action :admin_required, only: [:new, :create, :delete, :destroy]

  def index
    if current_user.admin?
      @organizations = Organization.present.order(:name).to_a
    else
      @organizations = current_user.organizations.present.order(:name).to_a
      if @organizations.size == 1 && params[:nrd].nil?
        redirect_to organization_root_path(@organizations.first)
      end
    end
  end

  def new
    @organization = Organization.new
  end

  def create
    @organization = Organization.new(params.require(:organization).permit(:name, :permalink))
    @organization.owner = current_user
    if @organization.save
      redirect_to_with_json organization_root_path(@organization)
    else
      render_form_errors "new", @organization
    end
  end

  def edit
    @organization_obj = current_user.organizations_scope.find(organization.id)
  end

  def update
    @organization_obj = current_user.organizations_scope.find(organization.id)
    if @organization_obj.update(params.require(:organization).permit(:name, :time_zone))
      redirect_to_with_json organization_settings_path(@organization_obj), notice: "Settings for #{@organization_obj.name} have been saved successfully."
    else
      render_form_errors "edit", @organization_obj
    end
  end

  def destroy
    unless current_user.authenticate(params[:password])
      respond_to do |wants|
        wants.html { redirect_to organization_delete_path(@organization), alert: "The password you entered was not valid. Please check and try again." }
        wants.json { render json: { alert: "The password you entered was invalid. Please check and try again." } }
      end
      return
    end

    organization.soft_destroy
    redirect_to_with_json root_path(nrd: 1), notice: "#{@organization.name} has been removed successfully."
  end

  private

  def organization
    if [:edit, :update, :delete, :destroy].include?(action_name.to_sym)
      @organization ||= params[:org_permalink] ? current_user.organizations_scope.find_by_permalink!(params[:org_permalink]) : nil
    end
  end
  helper_method :organization

end
