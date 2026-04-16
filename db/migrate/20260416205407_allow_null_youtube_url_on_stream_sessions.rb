class AllowNullYoutubeUrlOnStreamSessions < ActiveRecord::Migration[8.1]
  def change
    change_column_null :stream_sessions, :youtube_url, true
  end
end
