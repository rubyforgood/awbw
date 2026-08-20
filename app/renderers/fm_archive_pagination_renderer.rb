class FmArchivePaginationRenderer < TailwindPaginationRenderer
  protected

  def url(page)
    @template.url_for(
      @template.params.to_unsafe_h
               .merge(@options[:param_name] => page)
               .except(:controller, :action, :page)
    )
  end
end
