class SessionsController < ApplicationController

  layout "sub"

  skip_before_action :login_required, only: [:new, :create, :create_with_token, :begin_password_reset, :finish_password_reset, :ip, :raise_error]

  def create
    login(User.authenticate(params[:email_address], params[:password]))
    flash[:remember_login] = true
    redirect_to_with_return_to root_path
  rescue Postal::Errors::AuthenticationError => e
    flash.now[:alert] = "The credentials you've provided are incorrect. Please check and try again."
    render "new"
  end

  def create_with_token
    result = JWT.decode(params[:token], Postal.signing_key.to_s, "HS256")[0]
    if result["timestamp"] > 1.minute.ago.to_f
      login(User.find(result["user"].to_i))
      redirect_to root_path
    else
      destroy
    end
  rescue JWT::VerificationError
    destroy
  end

  def destroy
    auth_session.invalidate! if logged_in?
    reset_session
    redirect_to login_path
  end

  def persist
    auth_session.persist! if logged_in?
    render plain: "OK"
  end

  def begin_password_reset
    if request.post?
      if user = User.where(email_address: params[:email_address]).first
        user.begin_password_reset(params[:return_to])
        redirect_to login_path(return_to: params[:return_to]), notice: "Please check your e-mail and click the link in the e-mail we've sent you."
      else
        redirect_to login_reset_path(return_to: params[:return_to]), alert: "No user exists with that e-mail address. Please check and try again."
      end
    end
  end

  def finish_password_reset
    @user = User.where(password_reset_token: params[:token]).where("password_reset_token_valid_until > ?", Time.now).first
    if @user.nil?
      redirect_to login_path(return_to: params[:return_to]), alert: "This link has expired or never existed. Please choose reset password to try again."
    end

    if request.post?
      if params[:password].blank?
        flash.now[:alert] = "You must enter a new password"
        return
      end
      @user.password = params[:password]
      @user.password_confirmation = params[:password_confirmation]
      if @user.save
        login(@user)
        redirect_to_with_return_to root_path, notice: "Your new password has been set and you've been logged in."
      end
    end
  end

  def ip
    render plain: "ip: #{request.ip} remote ip: #{request.remote_ip}"
  end

end
