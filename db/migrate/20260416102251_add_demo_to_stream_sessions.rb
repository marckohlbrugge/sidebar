class AddDemoToStreamSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :stream_sessions, :demo, :boolean, null: false, default: false
    add_index :stream_sessions, :demo, where: "demo = 1"
  end
end
