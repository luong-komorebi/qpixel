class TwoFactorController < ApplicationController
  before_action :authenticate_user!

  def tf_status; end

  def enable_2fa
    if params[:method] == 'app'
      secret = ROTP::Base32.random
      current_user.update(two_factor_token: secret, two_factor_method: 'app')
      totp = ROTP::TOTP.new(secret, issuer: 'codidact.com')
      uri = totp.provisioning_uri("#{current_user.id}@users-2fa.codidact.com")
      qr_svg = RQRCode::QRCode.new(uri).as_svg
      @qr_uri = "data:image/svg+xml;base64,#{Base64.encode64(qr_svg)}"
    elsif params[:method] == 'email'
      current_user.update(two_factor_method: 'email', enabled_2fa: true)
      redirect_to two_factor_status_path
    else
      flash[:danger] = 'How did you get here?'
      redirect_to two_factor_status_path
    end
  end

  def enable_code; end

  def confirm_enable_code
    if current_user.two_factor_token.blank?
      flash[:danger] = "Missed a step! There's no 2FA token on your account."
      redirect_to two_factor_status_path && return
    end

    totp = ROTP::TOTP.new(current_user.two_factor_token)
    if totp.verify(params[:code], drift_behind: 15, drift_ahead: 15)
      current_user.update(enabled_2fa: true)
      flash[:success] = 'Success! 2FA has been enabled on your account.'
      redirect_to two_factor_status_path
    else
      flash[:danger] = "That's not the right code."
      redirect_to two_factor_enable_code_path
    end
  end

  def disable_code; end

  def confirm_disable_code
    if current_user.two_factor_token.blank?
      flash[:danger] = "I don't know how you got here, but something is badly wrong."
      redirect_to two_factor_status_path && return
    end

    totp = ROTP::TOTP.new(current_user.two_factor_token)
    if totp.verify(params[:code], drift_behind: 15, drift_ahead: 15)
      current_user.update(two_factor_token: nil, enabled_2fa: false)
      flash[:success] = 'Success! 2FA has been disabled on your account.'
      redirect_to two_factor_status_path
    else
      flash[:danger] = "That's not the right code."
      redirect_to two_factor_disable_code_path
    end
  end

  def send_disable_email
    TwoFactorMailer.with(user: current_user, host: request.hostname).disable_email.deliver_now
    flash[:success] = 'Check your inbox for an email to confirm you want to do this.'
    redirect_to two_factor_status_path
  end

  def disable_link
    target_user = User.find_by login_token: params[:token]
    unless current_user.id == target_user.id && target_user.login_token_expires_at >= DateTime.now
      flash[:danger] = 'There was something wrong with this link. Please request another link and try again.'
      redirect_to two_factor_status_path
    end
  end

  def confirm_disable_link
    current_user.update(two_factor_method: nil, enabled_2fa: false)
    flash[:success] = 'Success! 2FA has been disabled on your account.'
    redirect_to two_factor_status_path
  end
end
