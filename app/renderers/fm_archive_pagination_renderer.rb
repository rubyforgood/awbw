class FmArchivePaginationRenderer < TailwindPaginationRenderer
  protected

  def url(page)
    @template.url_for(
      @template.params.to_unsafe_h
               .except(:controller, :action)
               .except(*page_params)
               .merge(param_name => page)
    )
  end

  private

  def param_name
    @options[:param_name] || :page
  end

  # Sibling sections' page params must not ride along in a section's links,
  # or paging one section would freeze every other section at its old page.
  def page_params
    @template.params.keys.select { |key| key.to_s.end_with?("page") }
  end
end
