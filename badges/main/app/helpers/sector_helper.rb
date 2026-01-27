module SectorHelper
  def sector_button(sector, font_size: "text-md")
    link_to root_path(sector),
            class: "group inline-flex items-center gap-2 px-4 py-2
                  border border-purple-800 text-purple-500 rounded-lg
                  hover:bg-purple-800 hover:text-white transition-colors duration-200
                  #{font_size} shadow-sm leading-none whitespace-nowrap" do
      # --- Name: stays one line & turns white on hover ---
      content_tag(
        :span,
        sector.name.to_s.truncate(30),
        title: sector.name.to_s,
        class: "font-semibold text-gray-900 whitespace-nowrap group-hover:text-white"
      )
    end
  end
end
