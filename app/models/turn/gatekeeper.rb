class Turn::Gatekeeper
  MODEL = "claude-haiku-4-5"
  CONTEXT_TURNS = 3

  class Schema < RubyLLM::Schema
    string :action,
      enum: GateDecision::ACTIONS,
      description: "Which persona (if any) should react, or wait/none"
    string :reason, description: "One short sentence explaining the choice"
  end

  PROMPT = <<~PROMPT.freeze
    You are the casting director for a live-stream AI sidebar. You have four personas on the panel:

    - fact_checker — Gary. Stern producer. Fires when the turn contains a specific factual claim worth checking (numbers, dates, named events, records, first/largest/only).
    - context — Fred. Dry context guy. Fires when a short background fact, historical parallel, or lateral connection would sharpen the point.
    - comedy — Jackie. Comedy writer. Fires when the turn has a setup for a punchline, an absurd framing, or a deflatable metaphor.
    - troll — The cynic. Fires when the claim is hype, oversimplified, one-sided, or has obvious pushback.

    Pick one of: wait | none | fact_checker | context | comedy | troll.

    - wait: only when the turn is a literal fragment with no meaning on its own (cut off in the middle of a phrase). Rare in practice — most turns have enough meaning to react to.
    - none: the turn is truly banal filler (pleasantries, generic framing, repetitions of what was just said). Use sparingly.
    - otherwise: pick the persona with the best angle. Most turns in a live news or podcast stream have at least one good angle — lean into picking a persona rather than staying silent. When multiple fit, pick the one that hasn't spoken most recently.

    Return your pick in `action` and a short sentence in `reason`.
  PROMPT

  def initialize(turn)
    @turn = turn
  end

  def run!
    result = RubyLLM.chat(model: MODEL)
      .with_instructions(PROMPT)
      .with_schema(Schema.new)
      .ask(user_message)

    @turn.stream_session.increment!(:llm_call_count)

    @turn.create_gate_decision!(
      action: result.content["action"],
      reason: result.content["reason"],
      llm_model: MODEL
    )
  end

  private

  def user_message
    previous = @turn.stream_session.turns
      .where(id: ...@turn.id)
      .order(:id)
      .last(CONTEXT_TURNS)
      .map { |t| "- #{t.text}#{persona_suffix(t)}" }

    <<~MSG
      Recent turns (oldest to newest) — each "↳" line is what a persona already said:
      #{previous.presence&.join("\n") || "(none)"}

      Current turn to cast:
      #{@turn.text}
    MSG
  end

  def persona_suffix(turn)
    comment = turn.comments.last
    return unless comment
    "\n  ↳ #{comment.persona&.display_name || comment.personality}: #{comment.body}"
  end
end
