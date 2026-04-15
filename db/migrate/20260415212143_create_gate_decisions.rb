class CreateGateDecisions < ActiveRecord::Migration[8.1]
  def change
    create_table :gate_decisions do |t|
      t.references :turn, null: false, foreign_key: true, index: { unique: true }
      t.string :action, null: false
      t.text :reason
      t.string :llm_model, null: false

      t.timestamps
    end
  end
end
