class PersonaReactionJob < ApplicationJob
  queue_as :default

  def perform(turn, persona_key)
    session = turn.stream_session
    return if StreamSession.kill_switched? || session.killed?
    return if session.llm_call_count >= session.llm_call_cap

    persona = Turn::Persona.find(persona_key)
    return unless persona

    persona.new(turn).run!
  end
end
