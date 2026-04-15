class Comment < ApplicationRecord
  belongs_to :turn

  after_create_commit -> {
    session = turn.stream_session
    broadcast_replace_to(session, :timeline, target: ActionView::RecordIdentifier.dom_id(turn), partial: "turns/turn", locals: { turn: turn })
    broadcast_append_to(session, :timeline, target: "timeline", partial: "comments/comment", locals: { comment: self })
  }

  def persona
    Turn::Persona::Base.find(personality)
  end
end
