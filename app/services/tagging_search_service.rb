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
      workshops: authorized_scope(Workshop.all)
                   .includes(:sectors, :categories, :windows_type, :primary_asset, :gallery_assets, :bookmarks)
                   .sector_names_all(sector_names_all)
                   .category_names_all(category_names_all)
                   .order_by_date("desc")
                   .paginate(page: pages[:workshops] || 1, per_page: number_of_items_per_page)
                   .decorate,

      resources: authorized_scope(Resource.all)
                   .includes(:windows_type, :primary_asset, :gallery_assets)
                   .sector_names_all(sector_names_all)
                   .category_names_all(category_names_all)
                   .order(:title)
                   .paginate(page: pages[:resources] || 1, per_page: number_of_items_per_page)
                   .decorate,

      community_news: authorized_scope(CommunityNews.all)
                        .includes(:windows_type, :primary_asset, :gallery_assets)
                        .sector_names_all(sector_names_all)
                        .category_names_all(category_names_all)
                        .order(updated_at: :desc)
                        .paginate(page: pages[:community_news] || 1, per_page: number_of_items_per_page)
                        .decorate,

      events: authorized_scope(Event.all)
                .includes(:event_registrations, :primary_asset, :gallery_assets)
                .sector_names_all(sector_names_all)
                .category_names_all(category_names_all)
                .order(:start_date)
                .paginate(page: pages[:events] || 1, per_page: number_of_items_per_page)
                .decorate,

      stories: authorized_scope(Story.all)
                 .includes(:windows_type, :primary_asset, :gallery_assets)
                 .sector_names_all(sector_names_all)
                 .category_names_all(category_names_all)
                 .order(updated_at: :desc)
                 .paginate(page: pages[:stories] || 1, per_page: number_of_items_per_page)
                 .decorate,

      people: authorized_scope(Person.all)
                .includes(:sectors)
                .sector_names_all(sector_names_all)
                .category_names_all(category_names_all)
                .order(:first_name, :last_name)
                .paginate(page: pages[:people] || 1, per_page: number_of_items_per_page)
                .decorate,

      organizations: authorized_scope(Organization.all)
                  .includes(:sectors)
                  .sector_names_all(sector_names_all)
                  .category_names_all(category_names_all)
                  .order(:name)
                  .paginate(page: pages[:organizations] || 1, per_page: number_of_items_per_page)
                  .decorate,

      quotes: authorized_scope(Quote.all)
                .includes(:sectors, :primary_asset, :gallery_assets)
                .sector_names_all(sector_names_all)
                .category_names_all(category_names_all)
                .order(:quote)
                .paginate(page: pages[:quotes] || 1, per_page: number_of_items_per_page)
                .decorate,

      video_recordings: authorized_scope(VideoRecording.all)
                   .includes(:sectors, :categories, :primary_asset, :gallery_assets)
                   .sector_names_all(sector_names_all)
                   .category_names_all(category_names_all)
                   .order(:position, :title)
                   .paginate(page: pages[:video_recordings] || 1, per_page: number_of_items_per_page)
                   .decorate,

      # Admin-only: authorized_scope resolves to none for non-admins, so grants
      # only surface here for admins.
      grants: authorized_scope(Grant.all)
                .includes(:sectors, :categories)
                .sector_names_all(sector_names_all)
                .category_names_all(category_names_all)
                .by_deadline
                .paginate(page: pages[:grants] || 1, per_page: number_of_items_per_page)
                .decorate
    }
  end

  def self.empty_results(per_page)
    Tag::TAGGABLE_META.keys.index_with do
      WillPaginate::Collection.create(1, per_page || 9, 0) { |pager| pager.replace([]) }
    end
  end
end
