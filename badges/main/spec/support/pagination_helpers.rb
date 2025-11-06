module PaginationHelpers
	def paginated(collection, page: 1, per_page: 10)
		WillPaginate::Collection.create(page, per_page, collection.size) do |pager|
			pager.replace(collection)
		end
	end
end