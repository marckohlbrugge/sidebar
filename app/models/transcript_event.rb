class TranscriptEvent < ApplicationRecord
  belongs_to :stream_session

  scope :ordered, -> { order(:received_at, :id) }
  scope :finals, -> { where(is_final: true) }
  scope :speech_finals, -> { where(speech_final: true) }

  after_create_commit -> {
    broadcast_append_to(stream_session, :events, target: "events")
  }
end
