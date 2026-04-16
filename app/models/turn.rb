class Turn < ApplicationRecord
  belongs_to :stream_session
  has_one :gate_decision, dependent: :destroy
  has_many :comments, dependent: :destroy

  scope :ordered, -> { order(:finalized_at, :id) }

  broadcasts_to ->(turn) { [ turn.stream_session, :timeline ] },
    target: "timeline",
    inserts_by: :append,
    partial: "turns/turn"
  after_create_commit -> { AnalyzeTurnJob.perform_later(self) }

  def replay_offset_ms
    audio_start_ms || ((finalized_at - stream_session.replay_origin) * 1000).to_i
  end
end
