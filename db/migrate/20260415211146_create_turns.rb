class CreateTurns < ActiveRecord::Migration[8.1]
  def change
    create_table :turns do |t|
      t.references :stream_session, null: false, foreign_key: true
      t.text :text, null: false
      t.datetime :started_at
      t.datetime :ended_at
      t.datetime :finalized_at, null: false

      t.timestamps
    end
    add_index :turns, [ :stream_session_id, :finalized_at ]
  end
end
