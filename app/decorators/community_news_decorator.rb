class CommunityNewsDecorator < Draper::Decorator
  delegate_all

  def inactive?
    !published?
  end

  def title_with_badges(controller_name:)
    h.content_tag :div, class: "flex flex-col" do

      badge_row = h.content_tag :div, class: "flex flex-wrap items-center gap-2 mb-1" do
        fragments = []

        # Hidden badge
        if inactive? && controller_name != "dashboard"
          fragments << h.content_tag(
            :span,
            h.content_tag(:i, "", class: "fa-solid fa-eye-slash mr-1") + " Hidden",
            class: "inline-flex items-center px-2 py-0.5 rounded-full
                  text-sm font-medium bg-blue-100 text-gray-600 whitespace-nowrap"
          )
        end

        # Featured badge
        if featured? && controller_name != "dashboard"
          fragments << h.content_tag(
            :span,
            "🌟 Featured",
            class: "inline-flex items-center px-2 py-0.5 rounded-full
                  text-sm font-medium bg-yellow-100 text-yellow-800 whitespace-nowrap"
          )
        end

        fragments.join.html_safe
      end

      title_row = h.content_tag(
        :span,
        object.title.titleize,
        class: "text-lg font-semibold text-gray-900 leading-tight"
      )

      badge_row + title_row
    end
  end

end
