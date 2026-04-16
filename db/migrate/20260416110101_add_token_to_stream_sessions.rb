class AddTokenToStreamSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :stream_sessions, :token, :string
    add_index :stream_sessions, :token, unique: true
  end
end
