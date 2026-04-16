class AddRecordingMetadataToStreamSessionsAndTurns < ActiveRecord::Migration[8.1]
  def change
    add_column :stream_sessions, :live, :boolean, null: false, default: true
    add_column :turns, :audio_start_ms, :integer
    add_column :turns, :audio_end_ms, :integer
  end
end
