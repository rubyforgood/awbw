class Report < ApplicationRecord
  include Reportable

  def delete_and_update_all(quotes_params, log_fields, image = nil)
    # self.quotes.delete_all # TODO - figure out why this was deleting quotes and quote_item_quotes
    # self.report_form_field_answers.delete_all # TODO - figure out why this was deleting quotes and quote_item_quotes

    # self.quotes.build( quotes_params )
    # self.report_form_field_answers.build( log_fields )

    unless image.blank?
      self.image.destroy if self.image
      self.image = Image.new(file: image)
    end

    save
  end
end
