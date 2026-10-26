# Which records of a FilemakerCoded model carry each code, read once so a bulk import
# looks codes up in memory rather than scanning the table per archive row. Records the
# import codes as it goes are added with #add, so a later row finds them.
class FilemakerCodeIndex
  def initialize(model)
    @model = model
    @ids = Hash.new { |hash, code| hash[code] = [] }
    model.where.not(filemaker_code: [ nil, "" ]).pluck(:id, :filemaker_code).each do |id, value|
      model.split_filemaker_codes(value).each { |code| @ids[code] << id }
    end
  end

  def ids(code)
    @ids.fetch(@model.strip_filemaker_code(code), [])
  end

  def include?(code)
    ids(code).any?
  end

  def records(code)
    ids = ids(code)
    ids.empty? ? [] : @model.where(id: ids).order(:id).to_a
  end

  def add(code, id)
    code = @model.strip_filemaker_code(code)
    @ids[code] |= [ id ] if code.present?
  end

  def remove(code, id)
    @ids[@model.strip_filemaker_code(code)].delete(id)
  end
end
