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

  private

  def html
    Nokogiri::HTML(text)
  end

  def type_link
    h.link_to 'Resources', h.resources_path
  end
end
