class Comment < ApplicationRecord
  belongs_to :turn
  delegate :stream_session, to: :turn

  broadcasts_to ->(comment) { [ comment.stream_session, :timeline ] },
    target: "timeline",
    inserts_by: :append,
    partial: "comments/comment"

  def persona
    Turn::Persona.find(personality)
  end

  def replay_offset_ms
    ((created_at - stream_session.replay_origin) * 1000).to_i
  end
end
