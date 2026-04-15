class Turn < ApplicationRecord
  belongs_to :stream_session
  has_one :gate_decision, dependent: :destroy
  has_many :comments, dependent: :destroy

  scope :ordered, -> { order(:finalized_at, :id) }

  after_create_commit -> {
    broadcast_append_to(stream_session, :timeline, target: "timeline", partial: "turns/turn")
    AnalyzeTurnJob.perform_later(self)
  }
end
