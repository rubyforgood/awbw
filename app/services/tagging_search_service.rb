class TaggingSearchService
  def self.call(sector_names:, category_names: nil,
                pages: {}, number_of_items_per_page: nil)
    if sector_names.blank? && category_names.blank?
      return empty_results(number_of_items_per_page)
    end

    {
      workshops: Workshop
                   .includes(:sectors, :categories, :windows_type, :primary_asset, :gallery_assets)
                   .published
                   .sector_names(sector_names)
                   .category_names(category_names)
                   .order_by_date("desc")
                   .paginate(page: pages[:workshops] || 1, per_page: number_of_items_per_page)
                   .decorate,

      resources: Resource
                   .includes(:windows_type, :primary_asset, :gallery_assets)
                   .published
                   .sector_names(sector_names)
                   .category_names(category_names)
                   .order(:title)
                   .paginate(page: pages[:resources] || 1, per_page: number_of_items_per_page)
                   .decorate,

      community_news: CommunityNews
                        .includes(:windows_type, :primary_asset, :gallery_assets)
                        .published
                        .sector_names(sector_names)
                        .category_names(category_names)
                        .order(updated_at: :desc)
                        .paginate(page: pages[:community_news] || 1, per_page: number_of_items_per_page)
                        .decorate,

      events: Event
                .includes(:event_registrations, :primary_asset, :gallery_assets)
                .published
                .sector_names(sector_names)
                .category_names(category_names)
                .order(:start_date)
                .paginate(page: pages[:events] || 1, per_page: number_of_items_per_page)
                .decorate,

      stories: Story
                 .includes(:windows_type, :primary_asset, :gallery_assets)
                 .published
                 .sector_names(sector_names)
                 .category_names(category_names)
                 .order(updated_at: :desc)
                 .paginate(page: pages[:stories] || 1, per_page: number_of_items_per_page)
                 .decorate,

      facilitators: Facilitator
                      .includes(:sectors)
                      .published
                      .searchable
                      .sector_names(sector_names)
                      .category_names(category_names)
                      .order(:first_name, :last_name)
                      .paginate(page: pages[:facilitators] || 1, per_page: number_of_items_per_page)
                      .decorate,

      projects: Project
                  .includes(:sectors)
                  .published
                  .sector_names(sector_names)
                  .category_names(category_names)
                  .order(:name)
                  .paginate(page: pages[:projects] || 1, per_page: number_of_items_per_page)
                  .decorate,

      quotes: Quote
                .includes(:sectors, :primary_asset, :gallery_assets)
                .published
                .sector_names(sector_names)
                .category_names(category_names)
                .order(:quote)
                .paginate(page: pages[:quotes] || 1, per_page: number_of_items_per_page)
                .decorate
    }
  end

  def self.empty_results(per_page)
    Tag::TAGGABLE_META.keys.index_with do
      WillPaginate::Collection.create(1, per_page || 9, 0) { |pager| pager.replace([]) }
    end
  end
end
