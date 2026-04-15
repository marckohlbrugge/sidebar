class Comment < ApplicationRecord
  belongs_to :turn

  after_create_commit -> {
    session = turn.stream_session
    broadcast_append_to(session, :comments, target: "comments", partial: "comments/comment", locals: { comment: self })
  }

  def persona
    Turn::Persona::Base.find(personality)
  end
end
