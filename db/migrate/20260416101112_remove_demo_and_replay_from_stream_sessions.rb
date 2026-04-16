class RemoveDemoAndReplayFromStreamSessions < ActiveRecord::Migration[8.1]
  def change
    remove_index :stream_sessions, :demo, where: "demo = 1", if_exists: true
    remove_column :stream_sessions, :demo, :boolean, default: false, null: false
    remove_column :stream_sessions, :replay_pid, :integer
  end
end
