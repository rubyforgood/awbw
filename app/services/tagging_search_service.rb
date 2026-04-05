class TaggingSearchService
  include ActionPolicy::Behaviour
  authorize :user

  attr_reader :user

  def initialize(user:)
    @user = user
  end

  def call(sector_names_all:, category_names_all: nil,
           pages: {}, number_of_items_per_page: nil)
    if sector_names_all.blank? && category_names_all.blank?
      return self.class.empty_results(number_of_items_per_page)
    end

    {
      workshops: scope(Workshop)
                   .includes(:sectors, :categories, :windows_type, :primary_asset, :gallery_assets, :bookmarks)
                   .sector_names_all(sector_names_all)
                   .category_names_all(category_names_all)
                   .order_by_date("desc")
                   .paginate(page: pages[:workshops] || 1, per_page: number_of_items_per_page)
                   .decorate,

      resources: scope(Resource)
                   .includes(:windows_type, :primary_asset, :gallery_assets)
                   .sector_names_all(sector_names_all)
                   .category_names_all(category_names_all)
                   .order(:title)
                   .paginate(page: pages[:resources] || 1, per_page: number_of_items_per_page)
                   .decorate,

      community_news: scope(CommunityNews)
                        .includes(:windows_type, :primary_asset, :gallery_assets)
                        .sector_names_all(sector_names_all)
                        .category_names_all(category_names_all)
                        .order(updated_at: :desc)
                        .paginate(page: pages[:community_news] || 1, per_page: number_of_items_per_page)
                        .decorate,

      events: scope(Event)
                .includes(:event_registrations, :primary_asset, :gallery_assets)
                .sector_names_all(sector_names_all)
                .category_names_all(category_names_all)
                .order(:start_date)
                .paginate(page: pages[:events] || 1, per_page: number_of_items_per_page)
                .decorate,

      stories: scope(Story)
                 .includes(:windows_type, :primary_asset, :gallery_assets)
                 .sector_names_all(sector_names_all)
                 .category_names_all(category_names_all)
                 .order(updated_at: :desc)
                 .paginate(page: pages[:stories] || 1, per_page: number_of_items_per_page)
                 .decorate,

      people: scope(Person)
                .includes(:sectors)
                .sector_names_all(sector_names_all)
                .category_names_all(category_names_all)
                .order(:first_name, :last_name)
                .paginate(page: pages[:people] || 1, per_page: number_of_items_per_page)
                .decorate,

      organizations: scope(Organization)
                  .includes(:sectors)
                  .sector_names_all(sector_names_all)
                  .category_names_all(category_names_all)
                  .order(:name)
                  .paginate(page: pages[:organizations] || 1, per_page: number_of_items_per_page)
                  .decorate,

      quotes: scope(Quote)
                .includes(:sectors, :primary_asset, :gallery_assets)
                .sector_names_all(sector_names_all)
                .category_names_all(category_names_all)
                .order(:quote)
                .paginate(page: pages[:quotes] || 1, per_page: number_of_items_per_page)
                .decorate,

      video_recordings: scope(VideoRecording)
                   .includes(:sectors, :categories, :primary_asset, :gallery_assets)
                   .sector_names_all(sector_names_all)
                   .category_names_all(category_names_all)
                   .order(:position, :title)
                   .paginate(page: pages[:video_recordings] || 1, per_page: number_of_items_per_page)
                   .decorate
    }
  end

  def self.empty_results(per_page)
    Tag::TAGGABLE_META.keys.index_with do
      WillPaginate::Collection.create(1, per_page || 9, 0) { |pager| pager.replace([]) }
    end
  end

  private

  def scope(klass)
    authorized_scope(klass.all)
  end
end
