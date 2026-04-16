class Comment < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :turn
  delegate :stream_session, to: :turn

  after_create_commit :broadcast_arrival

  def persona
    Turn::Persona.find(personality)
  end

  def replay_offset_ms
    ((created_at - stream_session.replay_origin) * 1000).to_i
  end

  private

  def broadcast_arrival
    broadcast_replace_to stream_session, :timeline, target: dom_id(turn), partial: "turns/turn", locals: { turn: turn }
    broadcast_append_to  stream_session, :timeline, target: "timeline", partial: "comments/comment", locals: { comment: self }
  end
end
