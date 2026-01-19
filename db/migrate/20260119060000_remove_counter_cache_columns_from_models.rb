class RemoveCounterCacheColumnsFromModels < ActiveRecord::Migration[8.1]
  COUNTER_CACHES = {
    community_news: { view_count: { index: "index_community_news_on_view_count" } },
    events: { view_count: { index: "index_events_on_view_count" } },
    facilitators: { view_count: { index: "index_facilitators_on_view_count" } },
    projects: { view_count: { index: "index_projects_on_view_count" } },
    quotes: { view_count: { index: "index_quotes_on_view_count" } },
    stories: { view_count: { index: "index_stories_on_view_count" } },
    tutorials: { view_count: { index: "index_tutorials_on_view_count" } },
    workshop_variations: { view_count: { index: "index_workshop_variations_on_view_count" } },
    resources: {
      view_count:     { index: "index_resources_on_view_count" },
      print_count:    { index: "index_resources_on_print_count" },
      download_count: { index: "index_resources_on_download_count" } },
    workshops: {
      view_count:  { index: "index_workshops_on_view_count" },
      print_count: { index: "index_workshops_on_print_count" } }
  }.freeze

  def up
    COUNTER_CACHES.each do |table, columns|
      columns.each do |column, config|
        if config[:index] && index_exists?(table, name: config[:index])
          remove_index table, name: config[:index]
        end

        if column_exists?(table, column)
          remove_column table, column
        end
      end
    end
  end

  def down
    COUNTER_CACHES.each do |table, columns|
      columns.each do |column, config|
        unless column_exists?(table, column)
          add_column table, column, :integer, default: 0, null: false
        end

        if config[:index] && !index_exists?(table, name: config[:index])
          add_index table, column, name: config[:index]
        end
      end
    end
  end
end
