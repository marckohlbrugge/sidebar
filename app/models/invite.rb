class Invite < ApplicationRecord
  has_many :stream_sessions, dependent: :nullify

  has_secure_token :code

  validates :max_sessions, :max_turns_per_session, :max_llm_calls_per_session, numericality: { greater_than: 0 }

  scope :active, -> { where(revoked_at: nil) }

  def to_param
    code
  end

  def revoked?
    revoked_at.present?
  end

  def spent?
    sessions_used >= max_sessions
  end

  def available?
    !revoked? && !spent?
  end
end
