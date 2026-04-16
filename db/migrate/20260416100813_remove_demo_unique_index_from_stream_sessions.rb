class RemoveDemoUniqueIndexFromStreamSessions < ActiveRecord::Migration[8.1]
  def change
    remove_index :stream_sessions, :demo, unique: true, where: "demo = 1"
    add_index :stream_sessions, :demo, where: "demo = 1"
  end
end
