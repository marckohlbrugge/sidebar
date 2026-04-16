class Turn < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :stream_session
  has_one :gate_decision, dependent: :destroy
  has_many :comments, dependent: :destroy

  scope :ordered, -> { order(:finalized_at, :id) }

  after_create_commit :broadcast_arrival, :analyze_later

  def replay_offset_ms
    ((finalized_at - stream_session.replay_origin) * 1000).to_i
  end

  private

  def broadcast_arrival
    broadcast_append_to stream_session, :timeline, target: "timeline", partial: "turns/turn"
  end

  def analyze_later
    AnalyzeTurnJob.perform_later(self)
  end
end
