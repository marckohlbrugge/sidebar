class AnalyzeTurnJob < ApplicationJob
  queue_as :default

  LLM_CALL_CAP = 500
  COOLDOWN_TURNS = 3

  def perform(turn)
    session = turn.stream_session
    return if session.kill_switched?
    return if session.llm_call_count >= LLM_CALL_CAP

    decision = Turn::Gatekeeper.new(turn).run!
    persona = decision.persona
    return unless persona
    return if on_cooldown?(turn, persona)

    PersonaReactionJob.perform_later(turn, persona.key)
  end

  private

  def on_cooldown?(turn, persona)
    last_turn_id = Comment
      .joins(:turn)
      .where(turns: { stream_session_id: turn.stream_session_id })
      .where(personality: persona.key)
      .order(id: :desc)
      .limit(1)
      .pick(:turn_id)
    return false unless last_turn_id

    turns_since = turn.stream_session.turns.where(id: last_turn_id..turn.id).count - 1
    turns_since < COOLDOWN_TURNS
  end
end
