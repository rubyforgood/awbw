class WorkshopSearchService
  include ActionPolicy::Behaviour
  authorize :user

  attr_reader :params, :user, :admin
  attr_accessor :workshops, :sort

  def initialize(params = {}, user: nil)
    @params = params
    @user = user
    @admin = allowed_to?(:manage?, Workshop)
    @sort = default_sort
    @workshops = Workshop.all
    if @sort == "popularity"
      @workshops = @workshops.with_bookmarks_count
    end
  end

  # Main entry point
  def call
    filter_by_params
    order_by_params
    resolve_ids_order
    self # <- returns the WorkshopSearchService instance itself
  end

  # Compute the effective sort
  def default_sort
    params[:sort].presence || "created"
    # return params[:sort] if params[:sort].present?
    # return 'keywords' if params[:query].present? # only when returning weighted results from # search_by_query
    # 'title'
  end

  private

  # --- Filtering ---

  def filter_by_params
    filter_by_windows_type
    filter_by_windows_type_name
    filter_by_published_status
    filter_by_title
    filter_by_query
    filter_by_author_name
    filter_by_categories
    filter_by_sectors
    filter_by_tag_names
  end

  def filter_by_windows_type
    return unless params[:windows_types].present?
    ids = params[:windows_types].values.map(&:to_i)
    @workshops = @workshops.windows_type_ids(ids)
  end

  def filter_by_windows_type_name
    return unless params[:windows_type_name].present?
    @workshops = @workshops.windows_type_name(params[:windows_type_name])
  end

  def filter_by_published_status
    if admin
      pub   = params.key?(:published)   ? ActiveModel::Type::Boolean.new.cast(params[:published])   : nil
      unpub = params.key?(:unpublished) ? ActiveModel::Type::Boolean.new.cast(params[:unpublished]) : nil

      case [ pub, unpub ]
      when [ true, nil ], [ true, false ]
        @workshops = @workshops.published(true)     # ONLY published
      when [ nil, true ], [ false, true ]
        @workshops = @workshops.published(false)    # ONLY unpublished
      when [ false, false ]
        @workshops = @workshops.none                # NONE
      else # incl [ nil, nil ] && [ true, true ]
        @workshops                                  # ALL
      end
    elsif user
      @workshops = @workshops.published
    else
      @workshops = @workshops.publicly_visible
    end
  end

  def filter_by_author_name
    return unless params[:author_name].present?
    @workshops = search_by_author_name(@workshops, params[:author_name])
  end

  def filter_by_categories
    return unless params[:categories].present?
    @workshops = search_by_categories(@workshops, params[:categories])
  end

  def filter_by_sectors
    sector_ids = []

    # From dropdown IDs
    if params[:sectors].present?
      sector_ids += params[:sectors].to_unsafe_h.values.reject(&:blank?).map(&:to_i)
    end

    # From tagging links (?sector_names=...)
    sector_ids += sector_ids_from_names

    sector_ids.uniq!
    return if sector_ids.blank?

    @workshops = @workshops
        .joins(:sectorable_items)
        .where(
          sectorable_items: {
            sectorable_type: "Workshop",
            sector_id: sector_ids
          }
        )
        .distinct

    params[:sectors] ||= {}
    sector_ids.each { |id| params[:sectors][id.to_s] = id.to_s }
  end

  def filter_by_tag_names
    @workshops = @workshops.sector_names_all(@params[:sector_names_all]) if @params[:sector_names_all].present?
    @workshops = @workshops.category_names_all(@params[:category_names_all]) if @params[:category_names_all].present?
    @workshops
  end

  def filter_by_title
    return unless params[:title].present?
    @workshops = @workshops.search("title:#{params[:title]}")
  end

  def filter_by_query
    return unless params[:query].present?

    results = @workshops.search(params[:query]) # Use the SearchCop search scope directly on the relation

    # If SearchCop returned an Array (e.g., because of scoring), convert back to Relation
    if results.is_a?(Array)
      ordered_ids = results.map(&:id)
      @workshops = Workshop.where(id: ordered_ids)
                           .order(Arel.sql("FIELD(id, #{ordered_ids.join(',')})"))
    else
      @workshops = results
    end
  end

  # --- Search methods ---

  def search_by_author_name(workshops, author_name)
    return workshops if author_name.blank?

    sanitized = author_name.strip.gsub(/\s+/, "")
    workshops.left_outer_joins(:user)
             .where(
               "LOWER(REPLACE(workshops.full_name, ' ', '')) LIKE :name
                OR LOWER(REPLACE(CONCAT(users.first_name, users.last_name), ' ', '')) LIKE :name
                OR LOWER(REPLACE(CONCAT(users.last_name, users.first_name), ' ', '')) LIKE :name
                OR LOWER(REPLACE(users.first_name, ' ', '')) LIKE :name
                OR LOWER(REPLACE(users.last_name, ' ', '')) LIKE :name",
               name: "%#{sanitized}%"
             )
  end

  def search_by_categories(workshops, categories)
    ids = categories.to_unsafe_h.values.reject(&:blank?)
    return workshops if ids.empty?
    workshops.joins(:categorizable_items)
             .where(categorizable_items: { categorizable_type: "Workshop", category_id: ids })
             .distinct
  end

  def search_by_sectors(workshops, sectors)
    ids = sectors.to_unsafe_h.values.reject(&:blank?)
    return workshops if ids.empty?
    workshops.joins(:sectorable_items)
             .where(sectorable_items: { sectorable_type: "Workshop", sector_id: ids })
             .distinct
  end

  def sector_ids_from_names
    return [] if params[:sector_names_all].blank?

    names =
      params[:sector_names_all]
        .to_s
        .split("--")
        .map(&:strip)
        .reject(&:blank?)

    return [] if names.empty?

    Sector
      .names(names) # your case-insensitive / partial matching scope
      .pluck(:id)
  end

  # --- Sorting ---

  def order_by_params
    case sort
    when "created"
      @workshops = @workshops.order(
        Arel.sql(<<~SQL.squish)
        CASE WHEN year IS NOT NULL AND month IS NOT NULL THEN 1 ELSE 2 END ASC,
        year DESC,
        month DESC,
        created_at DESC,
        title ASC
      SQL
      )
    when "led"
      @workshops = @workshops.order(led_count: :desc, title: :asc)
    when "popularity"
      @workshops = @workshops.order(bookmarks_count: :desc, title: :asc)
    when "title"
      @workshops = @workshops.order(title: :asc)
    when "keywords"
      # already ordered
    else
      @workshops = @workshops.order(created_at: :asc, title: :asc)
    end
  end


  # --- Handle distinct + order by FIELD(id, ...) for complex joins ---
  def resolve_ids_order
    return if sort.in?(%w[keywords popularity])

    sort_columns =
      case sort
      when "created"    then [ :id, :created_at, :year, :month, :title ]
      when "led"        then [ :id, :led_count, :title ]
      when "popularity" then [ :id, :bookmarks_count, :title ]
      when "title"      then [ :id, :title ]
      else [ :id, :title ]
      end

    workshop_ids =
      @workshops
        .select(*sort_columns)
        .order(sort_columns)
        .map(&:id)

    @workshops =
      Workshop
        .where(id: workshop_ids)
        .order(Arel.sql("FIELD(id, #{workshop_ids.join(',')})"))
  end
end
