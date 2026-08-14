json.stories @stories, partial: "api/v1/stories/story", as: :story

json.meta do
  json.current_page @stories.current_page
  json.per_page @stories.per_page
  json.total_entries @stories.total_entries
  json.total_pages @stories.total_pages
end
