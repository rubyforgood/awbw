module StorySharesHelper
  # Story Share landing/nav slots get a fixed color by position (not by sector),
  # so whichever sector an admin drops into slot 1 renders red, slot 2 sky, etc.
  # Every class is a complete literal string so Tailwind's JIT scanner emits it
  # (interpolated fragments would silently render unstyled — see CLAUDE.md).
  SLOT_THEMES = [
    { heading: "text-red-700",     link: "text-red-700 hover:underline",     overlay: "bg-rose-800/80",    chip: "bg-red-700" },
    { heading: "text-sky-700",     link: "text-sky-700 hover:underline",     overlay: "bg-sky-700/80",     chip: "bg-sky-700" },
    { heading: "text-green-700",   link: "text-green-700 hover:underline",   overlay: "bg-emerald-700/80", chip: "bg-green-700" },
    { heading: "text-purple-700",  link: "text-purple-700 hover:underline",  overlay: "bg-purple-700/80",  chip: "bg-purple-700" },
    { heading: "text-indigo-700",  link: "text-indigo-700 hover:underline",  overlay: "bg-indigo-700/80",  chip: "bg-indigo-700" },
    { heading: "text-fuchsia-700", link: "text-fuchsia-700 hover:underline", overlay: "bg-fuchsia-800/80", chip: "bg-fuchsia-700" }
  ].freeze
  SPOTLIGHT_THEME = { heading: "text-purple-700", link: "text-purple-700 hover:underline", overlay: "bg-purple-700/80", chip: "bg-purple-700" }.freeze

  def story_share_slot_theme(index)
    SLOT_THEMES[index % SLOT_THEMES.size]
  end

  # The portal's mega-menu points at the main marketing site. Opens in a new tab
  # so visitors don't lose the story they were reading.
  AWBW_BASE = "https://awbw.org".freeze

  def awbw_menu_link(label, path, html_class: "hover:text-purple-700")
    link_to label, "#{AWBW_BASE}#{path}", target: "_blank", rel: "noopener noreferrer", class: html_class
  end

  # Featured sectors shown in the navbar focus-area row (first 6 by position).
  # Cached because it renders on every portal page and rarely changes.
  def story_share_nav_sectors
    Rails.cache.fetch("story_share_nav_sectors", expires_in: 1.hour) do
      Sector.story_share_featured.limit(StorySharesController::FEATURED_SECTOR_LIMIT).to_a
    end
  end

  # Audience categories (StoryPopulation) shown in the navbar's second row.
  def story_share_audience_categories
    Rails.cache.fetch("story_share_audience_categories", expires_in: 1.hour) do
      Category.story_share_featured.to_a
    end
  end

  # "Additional focus areas" dropdown: published sectors that aren't already
  # featured but do have at least one publicly-visible story.
  def additional_focus_area_sectors
    Rails.cache.fetch("story_share_focus_area_sectors", expires_in: 1.hour) do
      featured = story_share_nav_sectors.map(&:id)
      Sector.published.excluding_other.where.not(id: featured)
            .joins(:stories).merge(Story.publicly_visible)
            .distinct.order(:name).to_a
    end
  end

  # Heading for a filtered browse page. Sector/category names keep their stored
  # casing (never .titleize — commit #1921).
  def browse_title(params)
    return params[:sector_names_all].to_s.split("--").to_sentence if params[:sector_names_all].present?
    return params[:category_names_all].to_s.split("--").to_sentence if params[:category_names_all].present?
    return "Facilitator spotlights" if params[:facilitator_spotlights].present?
    return "Search results for “#{params[:query]}”" if params[:query].present?
    "All stories"
  end
end
