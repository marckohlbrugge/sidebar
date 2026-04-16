class RemoveDemoFromStreamSessions < ActiveRecord::Migration[8.1]
  def change
    remove_column :stream_sessions, :demo, :boolean, default: false, null: false
  end
end
