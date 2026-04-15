class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :turn, null: false, foreign_key: true
      t.string :personality
      t.text :body
      t.string :llm_model

      t.timestamps
    end
  end
end
