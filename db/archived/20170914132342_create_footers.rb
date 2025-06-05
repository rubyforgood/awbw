class CreateFooters < ActiveRecord::Migration[4.2]
  def change
    create_table :footers do |t|
      t.string :phone
      t.string :children_program
      t.string :adult_program
      t.string :general_questions

      t.timestamps null: false
    end

    Footer.create(phone: "310.396.0317", children_program: "cturekrials@awbw.org",
                  adult_program: "cturek@awbw.org",
                  general_questions: "programs@awbw.org")
  end
end
