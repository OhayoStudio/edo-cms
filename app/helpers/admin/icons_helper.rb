# Small outline icons and the icon-only row actions (edit, delete, publish,
# unpublish) used in admin and trials lists. Icons are decorative: each action
# carries its own aria-label naming the item, plus a tooltip.
module Admin::IconsHelper
  ADMIN_ICON_PATHS = {
    eye: [
      "M2.036 12.322a1.012 1.012 0 0 1 0-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178Z",
      "M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z"
    ],
    eye_slash: [
      "M3.98 8.223A10.477 10.477 0 0 0 1.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.451 10.451 0 0 1 12 4.5c4.756 0 8.773 3.162 10.065 7.498a10.522 10.522 0 0 1-4.293 5.774M6.228 6.228 3 3m3.228 3.228 3.65 3.65m7.894 7.894L21 21m-3.228-3.228-3.65-3.65m0 0a3 3 0 1 0-4.243-4.243m4.242 4.242L9.88 9.88"
    ],
    globe: [
      "M12 21a9.004 9.004 0 0 0 8.716-6.747M12 21a9.004 9.004 0 0 1-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 0 1 7.843 4.582M12 3a8.997 8.997 0 0 0-7.843 4.582m15.686 0A11.953 11.953 0 0 1 12 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0 1 21 12c0 .778-.099 1.533-.284 2.253m0 0A17.919 17.919 0 0 1 12 16.5c-3.162 0-6.133-.815-8.716-2.247m0 0A9.015 9.015 0 0 1 3 12c0-1.605.42-3.113 1.157-4.418"
    ],
    pencil: [
      "m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0 1 15.75 21H5.25A2.25 2.25 0 0 1 3 18.75V8.25A2.25 2.25 0 0 1 5.25 6H10"
    ],
    trash: [
      "m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
    ]
  }.freeze

  ICON_ACTION_BASE = "inline-flex items-center justify-center w-8 h-8 rounded transition-colors cursor-pointer"
  ICON_ACTION_CLASSES = {
    edit: "#{ICON_ACTION_BASE} border border-sage-deep text-sage-deep dark:border-peach dark:text-peach " \
          "hover:bg-peach-tint dark:hover:bg-sage-deep/20",
    delete: "#{ICON_ACTION_BASE} bg-red-600 hover:bg-red-700 text-white",
    publish: "#{ICON_ACTION_BASE} bg-green-600 hover:bg-green-700 text-white",
    unpublish: "#{ICON_ACTION_BASE} border border-gray-400 text-gray-600 dark:border-gray-500 dark:text-gray-300 " \
               "hover:bg-gray-100 dark:hover:bg-gray-700"
  }.freeze

  def admin_icon(name, css: "w-4 h-4")
    paths = ADMIN_ICON_PATHS.fetch(name)
    tag.svg(xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor",
            "stroke-width": "1.5", class: css, "aria-hidden": "true", focusable: "false") do
      safe_join(paths.map { |d| tag.path("stroke-linecap": "round", "stroke-linejoin": "round", d: d) })
    end
  end

  def admin_edit_icon_link(path, name:, tooltip: t("admin.common.edit"), **options)
    link_to path, class: ICON_ACTION_CLASSES[:edit], title: tooltip,
                  aria: { label: t("admin.common.edit_label", name: name) }, **options do
      admin_icon(:pencil)
    end
  end

  # Opens the shared confirm modal (admin-modal controller); `row` is the DOM id removed on success.
  def admin_delete_icon_button(url:, confirm_title:, name:, row: nil, tooltip: t("admin.common.delete"))
    data = { controller: "admin-modal", action: "click->admin-modal#open",
             admin_modal_url_value: url, admin_modal_title_value: confirm_title }
    data[:admin_modal_row_value] = row if row
    tag.button(type: "button", class: ICON_ACTION_CLASSES[:delete], title: tooltip,
               aria: { label: t("admin.common.delete_label", name: name) }, data: data) do
      admin_icon(:trash)
    end
  end

  def admin_publish_icon_button(path, name:)
    button_to path, method: :patch, class: ICON_ACTION_CLASSES[:publish], title: t("admin.common.publish"),
                    aria: { label: t("admin.common.publish_label", name: name) } do
      admin_icon(:globe)
    end
  end

  def admin_unpublish_icon_button(path, name:)
    button_to path, method: :patch, class: ICON_ACTION_CLASSES[:unpublish], title: t("admin.common.unpublish"),
                    aria: { label: t("admin.common.unpublish_label", name: name) } do
      admin_icon(:eye_slash)
    end
  end
end
