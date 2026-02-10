module PersonHelper
  def person_profile_button(person)
    link_to person_path(person),
            class: "group flex items-center gap-2
                    w-full px-4 py-2
                    border border-primary text-primary rounded-lg
                    hover:bg-primary hover:text-white transition-colors duration-200
                    font-medium shadow-sm leading-none
                    overflow-hidden" do
      person = person.decorate

      # --- Avatar ---
      avatar = if person.avatar.present?
        image_tag url_for(person.avatar),
                  class: "w-10 h-10 rounded-full object-cover border border-gray-300 shadow-sm flex-shrink-0"
      elsif person.user&.avatar.present?
        image_tag url_for(person.user.avatar),
                  class: "w-10 h-10 rounded-full object-cover border border-gray-300 shadow-sm flex-shrink-0"
      else
        image_tag "missing.png",
                  class: "w-10 h-10 rounded-full object-cover border border-dashed border-gray-300 flex-shrink-0"
      end

      # --- Name: stays one line & truncates ---
      name = content_tag(
        :span,
        person.name.to_s,
        title: person.name.to_s,
        class: "font-semibold text-gray-900 group-hover:text-white truncate"
      )

      # --- Pronouns ---
      pronouns = if person.pronouns_display.present?
        content_tag(
          :span,
          person.pronouns_display,
          class: "text-xs text-gray-500 italic group-hover:text-white truncate"
        )
      end

      text_block = content_tag(
        :div,
        safe_join([ name, pronouns ].compact),
        class: "flex flex-col leading-tight text-left min-w-0"
      )

      avatar + text_block
    end
  end
end
