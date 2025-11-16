class Search
  attr_accessor :params
  def initialize
  end

  def search(params, user)
    @params = params
    queries = process_params(params)
    klass = params[:type] ? params[:type].constantize : Workshop
    results = process_queries(klass, queries, user)
    return sort(results, klass)
  end

  private

  def process_queries(klass, queries, user)
    results = []

    if queries.any?
      queries.each do |query|
        category = Category.find_by_name(query)
        sector = Sector.find_by_name(query)

        if category
          results << category.workshops.published
        elsif sector
          results << sector.workshops.published
        else
          results.unshift(klass.search(query).for_search)
        end
      end
    else
      results << user.curriculum(klass).for_search
    end
    results.flatten.compact.uniq
  end

  def sort(objects, klass)
    return objects unless objects.any?
    sort_bys = sortable_params.select { |k, v| v == '1' }.keys

    return objects unless sort_bys.any?
    sorted = sort_bys.map(&:to_sym).map do  |sort_by|
      objects & klass.send("by_#{sort_by}")
    end

    sort_flat = sorted.flatten.uniq(&:title)

    sort_flat.sort_by!(&:led_count).reverse! if sort_flat.any? && sort_flat[0].send(:led_count) && sort_bys.include?('led_count')
    sort_flat.sort_by!(&:rating).reverse! if sort_flat.any? && sort_flat[0].class == Workshop && sort_flat[0].send(:rating) && sort_bys.include?('rating')
    sort_flat
  end

  def sortable_params
    params[:sort_by]
  end

  def process_params(params)
    queries = []
    params.each do |param, value|
      next if value.empty? || value == '0' || forbidden_params.include?(param)
      param == 'query' ? queries << value : queries << param
    end
    queries
  end

  def forbidden_params
    ['sort_by', 'type', 'sortable_items', 'page', 'view_all']
  end
end
