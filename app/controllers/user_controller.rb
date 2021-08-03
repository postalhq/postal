class UserController < ApplicationController

  skip_before_action :login_required, only: [:new, :create, :join]

  def new
    @user_invite = UserInvite.active.find_by!(uuid: params[:invite_token])
    @user = User.new
    @user.email_address = @user_invite.email_address
    render layout: "sub"
  end

  def create
    @user_invite = UserInvite.active.find_by!(uuid: params[:invite_token])
    @user = User.new(params.require(:user).permit(:first_name, :last_name, :email_address, :password, :password_confirmation))
    @user.email_verified_at = Time.now
    if @user.save
      @user_invite.accept(@user)
      self.current_user = @user
      redirect_to root_path
    else
      render "new", layout: "sub"
    end
  end

  def join
    if @invite = UserInvite.where(uuid: params[:token]).where("expires_at > ?", Time.now).first
      if logged_in?
        if request.post?
          @invite.accept(current_user)
          redirect_to_with_json root_path(nrd: 1), notice: "Invitation has been accepted successfully. You now have access to this organization."
        elsif request.delete?
          @invite.reject
          redirect_to_with_json root_path(nrd: 1), notice: "Invitation has been rejected successfully."
        else
          @organizations = @invite.organizations.order(:name).to_a
        end
      else
        redirect_to new_signup_path(params[:token])
      end
    else
      redirect_to_with_json root_path(nrd: 1), alert: "The invite URL you have has expired. Please ask the person who invited you to re-send your invitation."
    end
  end

  def edit
    @user = User.find(current_user.id)
  end

  def update
    @user = User.find(current_user.id)
    @user.attributes = params.require(:user).permit(:first_name, :last_name, :time_zone, :email_address, :password, :password_confirmation)

    if @user.authenticate_with_previous_password_first(params[:password])
      @password_correct = true
    else
      respond_to do |wants|
        wants.html do
          flash.now[:alert] = "The current password you have entered is incorrect. Please check and try again."
          render "edit"
        end
        wants.json do
          render json: { alert: "The current password you've entered is incorrect. Please check and try again" }
        end
      end
      return
    end

    email_changed = @user.email_address_changed?

    if @user.save
      if email_changed
        redirect_to_with_json verify_path(return_to: settings_path), notice: "Your settings have been updated successfully. As you've changed, your e-mail address you'll need to verify it before you can continue."
      else
        redirect_to_with_json settings_path, notice: "Your settings have been updated successfully."
      end
    else
      render_form_errors "edit", @user
    end
  end

  def verify
    if request.post?
      if params[:code].to_s.strip == current_user.email_verification_token.to_s || (Rails.env.development? && params[:code].to_s.strip == "123456")
        current_user.verify!
        redirect_to_with_json [:return_to, root_path], notice: "Thanks - your e-mail address has been verified successfully."
      else
        flash_now :alert, "The code you've entered isn't correct. Please check and try again."
      end
    end
  end

end
