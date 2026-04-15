class AddVideoIdToStreamSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :stream_sessions, :video_id, :string
  end
end
