module AnalyticsHelper
  def print_button(record,
                   printable_type: nil,
                   path: admin_analytics_print_path,
                   button_class: "btn btn-utility",
                   icon_class: "fas fa-print",
                   button_text: "Print",
                   title: "Print",
                  image_toggle: false)
    model = record.respond_to?(:object) ? record.object : record

    resolved_type =
      case printable_type
      when Class  then printable_type.name
      when String then printable_type
      else             model.class.name
      end.delete_suffix("Decorator")

    # The print button content
    print_content = safe_join([
      tag.i(class: icon_class),
      tag.span(button_text, class: "ml-1")
    ])

    # image hidden toggle
    toggle_div = if image_toggle
      tag.div(
      id: "print-images-toggle",
      title: "Toggle images",
      class: "inline-flex items-center cursor-pointer select-none ml-2 border-l-2 pl-2"
    ) do
      safe_join([
        icon("image-check", class: "w-5 h-5 animate-fade", id: "image-check-icon"),
        icon("image-x", class: "w-5 h-5 animate-fade hidden", id: "image-x-icon")
      ])
    end
    end

    # Wrap both in an outer inline-flex container
    tag.div(class: "inline-flex items-center #{button_class} ") do
      safe_join([
        # Print link
        link_to("#",
                title: title,
                data: {
                  printableType: resolved_type,
                  printableId: model.id
                },
                onclick: <<~JS.squish
                  window.print();
                  fetch("#{path}", {
                    method: "POST",
                    headers: {
                      "Content-Type": "application/json",
                      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
                    },
                    body: JSON.stringify({
                      printable_type: "#{resolved_type}",
                      printable_id: #{model.id}
                    })
                  });
                  return false;
                JS
        ) do
          print_content
        end,
        toggle_div
      ])
    end
  end
end
