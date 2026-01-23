module AnalyticsHelper
  def print_button(record,
                   printable_type: nil,
                   path: admin_analytics_print_path,
                   button_class: "btn btn-utility",
                   icon_class: "fas fa-print",
                   button_text: nil,
                   title: "Print")
    model = record.respond_to?(:object) ? record.object : record

    resolved_type =
      case printable_type
      when Class  then printable_type.name
      when String then printable_type
      else             model.class.name
      end.delete_suffix("Decorator")

    content = safe_join(
      [
        tag.i(class: icon_class),
        (tag.span(button_text, class: "ml-1") if button_text.present?)
      ].compact
    )

    link_to "#",
            class: button_class,
            title: title,
            data: {
              printableType: resolved_type,
              printableId: model.id
            },
            onclick: <<~JS.squish do
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
      content
    end
  end
end
