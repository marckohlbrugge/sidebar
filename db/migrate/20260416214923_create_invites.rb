class CreateInvites < ActiveRecord::Migration[8.1]
  def change
    create_table :invites do |t|
      t.string :code, null: false
      t.string :label
      t.integer :max_sessions, default: 5, null: false
      t.integer :sessions_used, default: 0, null: false
      t.integer :max_turns_per_session, default: 50, null: false
      t.integer :max_llm_calls_per_session, default: 20, null: false
      t.datetime :revoked_at

      t.timestamps
    end
    add_index :invites, :code, unique: true

    add_reference :stream_sessions, :invite, foreign_key: true
  end
end
