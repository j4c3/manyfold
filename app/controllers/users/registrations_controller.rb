# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  before_action :random_delay, only: [:create, :cancel]
  before_action :configure_sign_up_params, only: [:create]
  before_action :detect_if_first_use, only: [:edit, :update]
  before_action :load_languages, only: [:edit, :update]
  before_action :configure_account_update_params, only: [:update]
  skip_before_action :check_for_first_use, only: [:edit, :update]

  # GET /resource/sign_up
  def new
    authorize User
    super
  end

  # GET /resource/edit
  def edit
    authorize current_user
    if @first_use
      render "first_use"
    else
      super
    end
  end

  # POST /users
  def create
    authorize User
    super do |user|
      user.update(approved: false) if SiteSettings.approve_signups
    end
  end

  # PUT /resource
  def update
    authorize current_user
    if @first_use
      if current_user.update(account_update_params.merge(reset_password_token: nil))
        sign_in(current_user, bypass: true)
        redirect_to root_path, notice: t("devise.registrations.update.setup_complete")
      else
        render "first_use"
      end
    else
      super
    end
  end

  # DELETE /resource
  def destroy
    authorize current_user
    super
  end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  def cancel
    authorize :"users/registrations"
    super
  end

  protected

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [:username])
  end

  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update) do |user|
      user.permit(
        :email,
        :password,
        :password_confirmation,
        :current_password,
        :interface_language,
        :sensitive_content_handling,
        pagination_settings: [
          :models,
          :creators,
          :collections,
          :per_page
        ],
        tag_cloud_settings: [
          :threshold,
          :heatmap,
          :keypair,
          :sorting
        ],
        file_list_settings: [
          :hide_presupported_versions
        ],
        renderer_settings: [
          :grid_width,
          :grid_depth,
          :show_grid,
          :enable_pan_zoom,
          :background_colour,
          :object_colour,
          :render_style,
          :auto_load_max_size
        ],
        problem_settings: Problem::CATEGORIES
      )
    end
  end

  def detect_if_first_use
    if current_user.reset_password_token == "first_use"
      @first_use = true
      devise_parameter_sanitizer.permit(:account_update, keys: [:username])
    end
  end

  # The path used after sign up.
  # def after_sign_up_path_for(resource)
  #   super(resource)
  # end

  # The path used after sign up for inactive accounts.
  # def after_inactive_sign_up_path_for(resource)
  #   super(resource)
  # end

  # The path used after edit/update
  def after_update_path_for(resource)
    edit_user_registration_path
  end

  def pagination_json(settings)
    return nil unless settings
    {
      "models" => settings[:models] == "1",
      "creators" => settings[:creators] == "1",
      "collections" => settings[:collections] == "1",
      "per_page" => settings[:per_page].to_i
    }
  end

  def tag_cloud_json(settings)
    return nil unless settings
    {
      "threshold" => settings[:threshold].to_i,
      "heatmap" => settings[:heatmap] == "1",
      "keypair" => settings[:keypair] == "1"
    }
  end

  def file_list_json(settings)
    return nil unless settings
    {
      "hide_presupported_versions" => settings[:hide_presupported_versions] == "1"
    }
  end

  def renderer_json(settings)
    return nil unless settings
    {
      "grid_width" => settings[:grid_width].to_i,
      "grid_depth" => settings[:grid_width].to_i, # Store width in both for now. See #834
      "show_grid" => settings[:show_grid] == "1",
      "enable_pan_zoom" => settings[:enable_pan_zoom] == "1",
      "background_colour" => settings[:background_colour],
      "object_colour" => settings[:object_colour],
      "render_style" => settings[:render_style],
      "auto_load_max_size" => settings[:auto_load_max_size].to_i
    }
  end

  def load_languages
    @languages = [[t("devise.registrations.general_settings.interface_language.autodetect"), nil]].concat(
      I18n.available_locales.map { |locale| [I18nData.languages(locale)[locale.upcase.to_s]&.capitalize, locale] }
    )
  end

  def update_resource(resource, data)
    # Transform form data to crrect types
    data[:pagination_settings] = pagination_json(data[:pagination_settings])
    data[:renderer_settings] = renderer_json(data[:renderer_settings])
    data[:tag_cloud_settings] = tag_cloud_json(data[:tag_cloud_settings])
    data[:file_list_settings] = file_list_json(data[:file_list_settings])
    # Require password if important details have changed
    if (data[:email] && (data[:email] != resource.email)) || data[:password].present?
      resource.update_with_password(data)
    else
      resource.update_without_password(data.except(:email, :password, :password_confirmation, :current_password))
    end
  end
end
