class CreateStreamSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :stream_sessions do |t|
      t.string :youtube_url, null: false
      t.string :status, null: false, default: "idle"
      t.datetime :started_at
      t.datetime :stopped_at
      t.integer :llm_call_count, null: false, default: 0

      t.timestamps
    end
  end
end
