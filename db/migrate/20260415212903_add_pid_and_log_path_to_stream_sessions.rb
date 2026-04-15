class AddPidAndLogPathToStreamSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :stream_sessions, :pid, :integer
    add_column :stream_sessions, :log_path, :string
  end
end
