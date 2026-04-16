class GateDecision < ApplicationRecord
  include ActionView::RecordIdentifier

  ACTIONS = %w[wait none fact_checker context comedy troll].freeze
  PERSONA_ACTIONS = %w[fact_checker context comedy troll].freeze

  belongs_to :turn

  validates :action, inclusion: { in: ACTIONS }

  after_create_commit :broadcast_arrival

  def persona_action?
    PERSONA_ACTIONS.include?(action)
  end

  def persona
    Turn::Persona.find(action) if persona_action?
  end

  def badge_label
    persona_action? ? "#{persona.emoji} #{persona.display_name}" : action.upcase
  end

  private

  def broadcast_arrival
    broadcast_replace_to turn.stream_session, :timeline, target: dom_id(turn), partial: "turns/turn", locals: { turn: turn }
  end
end
