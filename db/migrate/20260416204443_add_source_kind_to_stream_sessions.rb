class AddSourceKindToStreamSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :stream_sessions, :source_kind, :string, default: "url", null: false
  end
end
