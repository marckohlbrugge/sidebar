class CreateTranscriptEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :transcript_events do |t|
      t.references :stream_session, null: false, foreign_key: true
      t.json :payload, null: false
      t.string :kind, null: false
      t.boolean :is_final, null: false, default: false
      t.boolean :speech_final, null: false, default: false
      t.text :transcript
      t.datetime :received_at, null: false

      t.timestamps
    end
    add_index :transcript_events, [ :stream_session_id, :received_at ]
  end
end
