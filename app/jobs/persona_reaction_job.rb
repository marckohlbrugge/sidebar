class PersonaReactionJob < ApplicationJob
  queue_as :default

  def perform(turn, persona_key)
    session = turn.stream_session
    return if session.kill_switched?
    return if session.llm_call_count >= AnalyzeTurnJob::LLM_CALL_CAP

    persona = Turn::Persona::Base.find(persona_key)
    return unless persona

    persona.new(turn).run!
  end
end
