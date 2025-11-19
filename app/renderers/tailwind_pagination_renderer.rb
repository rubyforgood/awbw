require 'will_paginate/view_helpers/action_view'
class TailwindPaginationRenderer < WillPaginate::ActionView::LinkRenderer
	def prepare(collection, options, template)
		super
		@template = template
		@options = options
	end

	def to_html
		html = pagination.map do |item|
			case item
			when :previous_page then previous_page
			when :next_page then next_page
			when :gap then gap
			else page_number(item)
			end
		end.join.html_safe

		@template.content_tag(:ul, html, class: "flex items-center gap-2")
	end

	protected

	def url(page)
		@template.url_for(
			@template.params.to_unsafe_h
							 .merge(page: page)               # set new page
							 .except(:controller, :action)    # avoid controller/action pollution
		)
	end

	def html_container(html)
		@template.tag.ul(html, class: "flex gap-2")
	end

	# page number
	def page_number(page)
		if page == current_page
			@template.tag.span(
				page, class: active_page_classes
			)
		else
			link(page,
					 page,
					 class: page_link_classes)
		end
	end

	# previous & next
	def previous_or_next_page(page, text, classname)
		if page
			link(text,
					 page,
					 class: arrow_classes)
		else
			disabled_arrow(text)
		end
	end

	# ellipsis
	def gap
		@template.tag.span("…", class: gap_classes)
	end

	def disabled_arrow(text)
		@template.tag.span(
			text,
			class: "disabled-arrow-classes px-3 py-1
              bg-transparent text-transparent"
		)
	end

	#### Helpers ####

	def wrap_li(inner)
		@template.content_tag(:li, inner, class: "page-item")
	end

	private

	def arrow_classes
		"arrow-classes px-3 py-1 border border-gray-200 rounded-md
     bg-white text-gray-300 hover:bg-gray-100 hover:text-gray-200"
	end

	def active_page_classes
		"active-classes px-3 py-1 rounded-md bg-transparent text-gray-700"
	end

	def page_link_classes
		"page-link-classes px-3 py-1 border border-gray-200 rounded-md
     bg-white text-gray-300 hover:bg-gray-100 hover:text-gray-200"
	end

	def gap_classes
		"gap-classes px-3 py-1 text-gray-300"
	end
end
