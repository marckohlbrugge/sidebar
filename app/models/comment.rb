class Comment < ApplicationRecord
  belongs_to :turn
  delegate :stream_session, to: :turn

  def replay_offset_ms
    origin = stream_session.replay_origin
    return 0 unless origin
    ((created_at - origin) * 1000).to_i
  end

  after_create_commit -> {
    session = turn.stream_session
    broadcast_replace_to(session, :timeline, target: ActionView::RecordIdentifier.dom_id(turn), partial: "turns/turn", locals: { turn: turn })
    broadcast_append_to(session, :timeline, target: "timeline", partial: "comments/comment", locals: { comment: self })
  }

  def persona
    Turn::Persona::Base.find(personality)
  end
end
