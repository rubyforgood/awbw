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

  # Curated sector-chip background per sector (complete literal classes so
  # Tailwind's JIT emits them). Featured sectors match their nav-slot colors.
  # No color is stored in the DB, so this is the source of truth; unmapped names
  # fall back to a deterministic pick from CHIP_COLORS.
  SECTOR_COLORS = {
    "Domestic Violence" => "bg-red-700",
    "Self-Care/Personal Growth" => "bg-sky-700",
    "Racial/Social Justice" => "bg-green-700",
    "Batterers Intervention" => "bg-stone-700",
    "Child Abuse/Neglect" => "bg-rose-700",
    "Climate/Environmental" => "bg-emerald-700",
    "Community Building" => "bg-amber-700",
    "Community Violence" => "bg-red-800",
    "Court/Legal System" => "bg-slate-700",
    "Disability Services" => "bg-cyan-700",
    "Education" => "bg-indigo-700",
    "Foster Care/Adoption" => "bg-blue-700",
    "Fundraising/Donor Engagement" => "bg-yellow-700",
    "Grief/Loss" => "bg-fuchsia-800",
    "Health/Medical" => "bg-teal-700",
    "Homelessness" => "bg-orange-700",
    "Human Trafficking" => "bg-rose-800",
    "Immigration" => "bg-lime-700",
    "Incarceration" => "bg-gray-700",
    "Indigenous/Tribal Nation" => "bg-amber-800",
    "LGBTQIA+" => "bg-purple-600",
    "Mental Health" => "bg-sky-800",
    "Military/Veterans" => "bg-green-800",
    "Private Practice/Sole Proprietor" => "bg-slate-600",
    "Religious/Faith-Based" => "bg-violet-700",
    "Reproductive Services" => "bg-pink-700",
    "Restorative/Transformative Justice" => "bg-emerald-800",
    "Sexual Assault" => "bg-fuchsia-700",
    "Staff/Organizational Development" => "bg-gray-800",
    "Substance Use/Recovery" => "bg-orange-800",
    "Systems/Policy Change" => "bg-blue-800",
    "Other" => "bg-gray-600"
  }.freeze
  CHIP_COLORS = %w[
    bg-red-700 bg-sky-700 bg-green-700 bg-purple-700 bg-indigo-700 bg-fuchsia-800
    bg-rose-800 bg-teal-700 bg-amber-700 bg-emerald-700 bg-violet-700 bg-cyan-700
  ].freeze

  def story_share_sector_chip_class(name)
    SECTOR_COLORS.fetch(name.to_s) { CHIP_COLORS[name.to_s.sum % CHIP_COLORS.size] }
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
    return "Additional Focus Areas" if params[:additional_focus_areas].present?
    return params[:sector_names_all].to_s.split("--").to_sentence if params[:sector_names_all].present?
    return params[:category_names_all].to_s.split("--").to_sentence if params[:category_names_all].present?
    return "Facilitator Spotlights" if params[:facilitator_spotlights].present?
    return "Search results for “#{params[:query]}”" if params[:query].present?
    "All stories"
  end
end
