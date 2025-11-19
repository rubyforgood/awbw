class ResourceDecorator < Draper::Decorator
  delegate_all

  def featured_url
    return "" if url.nil?
    url.empty? ? h.resource_path(resource) : url
  end

  def truncated_author
    h.truncate author, length: 20
  end

  def truncated_title
    h.truncate title, length: 25
  end

  def truncated_text(ln = 100)
    h.truncate(html.text.gsub(/(<[^>]+>)/, ''), length: ln)
  end

  def display_title
    title || kind
  end

  def flex_text
    h.truncate(html.text, length: 200)
  end

  def breadcrumbs
    "#{type_link} >> #{title}".html_safe
  end

  def author_full_name
    author || "#{user.first_name} #{user.last_name}"
  end

  def display_date
    created_at.strftime('%B %Y')
  end

  def display_text
    "<div class='reset-list-items'>#{text}</div>".html_safe
  end

  def card_class
    kind == 'Theme' ? 'circular-border' : 'normal'
  end

  def toolkit_and_form?
    kind == 'ToolkitAndForm'
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

  private

  def html
    Nokogiri::HTML(text)
  end

  def type_link
    h.link_to 'Resources', h.resources_path
  end
end
