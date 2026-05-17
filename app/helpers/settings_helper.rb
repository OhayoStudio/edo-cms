module SettingsHelper
  def cms_setting
    @_cms_setting ||= Setting.instance
  end

  def cms_color(name)
    cms_setting.theme_color(name)
  end

  def cms_theme_style_tag
    css = Setting::THEME_DEFAULTS.keys.map { |name|
      "--cms-#{name.tr('_', '-')}: #{cms_color(name)};"
    }.join(" ")
    content_tag(:style, ":root { #{css} }".html_safe)
  end
end
