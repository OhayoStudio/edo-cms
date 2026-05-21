class Admin::SettingsController < Admin::BaseController
  def edit
    @setting = Setting.instance
  end

  def update
    @setting = Setting.instance

    apply_nav_textareas
    apply_theme_colors

    if @setting.update(setting_params)
      redirect_to edit_admin_setting_path, notice: "Settings updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def setting_params
    params.require(:setting).permit(
      :site_name, :tagline, :meta_description, :contact_email,
      :analytics_provider, :analytics_website_id, :analytics_host,
      :newsletter_provider, :newsletter_form_action,
      :logo_light, :logo_dark, :favicon, :og_default_image,
      social_links: %i[twitter instagram github mastodon rss]
    )
  end

  # Nav items are stored as arrays of registry keys (one per line in the
  # textarea). The renderer (SettingsHelper#nav_registry) maps each key
  # to a translated label + locale-aware path, so editors don't worry
  # about i18n or URL prefixing.
  def apply_nav_textareas
    nav = {}
    %i[primary footer].each do |key|
      raw = params.dig(:setting, :"nav_items_#{key}").to_s
      nav[key.to_s] = raw.lines.map(&:strip).reject(&:blank?)
    end
    @setting.nav_items = nav
  end

  def apply_theme_colors
    incoming = params.dig(:setting, :theme_colors) || {}
    cleaned  = Setting::THEME_DEFAULTS.keys.each_with_object({}) do |name, acc|
      value = incoming[name].to_s.strip
      acc[name] = value if value.present?
    end
    @setting.theme_colors = cleaned
  end
end
