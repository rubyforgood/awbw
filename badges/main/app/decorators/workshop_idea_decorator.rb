class WorkshopIdeaDecorator < Draper::Decorator
  delegate_all

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end

  def display_spanish_fields
    [
      :objective_spanish, :materials_spanish, :optional_materials_spanish,
      :age_range_spanish, :setup_spanish,
      :introduction_spanish, :demonstration_spanish, :opening_circle_spanish,
      :warm_up_spanish, :visualization_spanish, :creation_spanish,
      :closing_spanish, :notes_spanish, :tips_spanish # :timeframe_spanish,
    ]
  end

  def labels_spanish
    {
      objective_spanish: 'Objectivo',
      materials_spanish: 'Materiales',
      optional_materials_spanish: 'Materiales Opcionales',
      timeframe_spanish: 'Periodo de tiempo',
      age_range_spanish: 'Rango de edad',
      setup_spanish: 'Preparativos',
      introduction_spanish: 'Introducción',
      demonstration_spanish: 'Demostración',
      opening_circle_spanish: 'Círculo de apertura',
      visualization_spanish: 'Visualización',
      warm_up_spanish: 'Comenzando',
      creation_spanish: 'Creación',
      closing_spanish: 'Clausura',
      misc_instructions_spanish: 'Instrucciones de misceláneos',
      project_spanish: 'Projecto',
      description_spanish: 'Descripción',
      notes_spanish: 'Notas',
      tips_spanish: 'Consejos',
    }
  end
end
