class Turn::Gatekeeper
  MODEL = "grok-4-1-fast-non-reasoning"
  CONTEXT_TURNS = 3

  class Schema < RubyLLM::Schema
    string :action,
      enum: GateDecision::ACTIONS,
      description: "Which persona (if any) should react, or wait/none"
    string :reason, description: "One short sentence explaining the choice"
    boolean :directly_invoked,
      description: "True if the speaker called on this persona by name or explicitly asked for their job (e.g. 'hey Gary', 'fact-check this', 'Fred, what's the context?'). False for content-based routing.",
      required: false
  end

  PROMPT = <<~PROMPT.freeze
    You are the casting director for a live-stream AI sidebar. You have four personas on the panel:

    - fact_checker — Gary. Stern producer. Fires when the turn contains a specific factual claim worth checking (numbers, dates, named events, records, first/largest/only), OR when the speaker addresses "Gary" or asks to "check", "fact-check", "verify", "look that up", "is that true".
    - context — Fred. Dry context guy. Fires when a short background fact, historical parallel, or lateral connection would sharpen the point, OR when the speaker addresses "Fred" or asks for "context", "background", "history".
    - comedy — Jackie. Comedy writer. Fires when the turn has a setup for a punchline, an absurd framing, or a deflatable metaphor, OR when the speaker addresses "Jackie" by name. Do NOT fire just because the word "joke" or "funny" appears.
    - troll — The cynic. Fires when the claim is hype, oversimplified, one-sided, or has obvious pushback, OR when the speaker addresses "Troll" by name. Do NOT fire just because the word "skeptic" or "pushback" appears.

    Pick one of: wait | none | fact_checker | context | comedy | troll.

    - wait: only when the turn is a literal fragment with no meaning on its own (cut off in the middle of a phrase). Rare in practice — most turns have enough meaning to react to.
    - none: the turn is truly banal filler (pleasantries, generic framing, repetitions of what was just said). Use sparingly.
    - otherwise: pick the persona with the best angle. **Direct address from the speaker overrides content-based routing** — if the speaker invokes a persona by name or asks for their job, pick that persona even if the content alone wouldn't warrant it. Most turns in a live news or podcast stream have at least one good angle — lean into picking a persona rather than staying silent. When multiple fit, pick the one that hasn't spoken most recently.

    Set `directly_invoked` to true if your choice was driven by the speaker invoking the persona by name or explicit request, false otherwise. Return `action` and a short `reason`.
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

    decision = @turn.create_gate_decision!(
      action: result.content["action"],
      reason: result.content["reason"],
      llm_model: MODEL
    )
    [ decision, !!result.content["directly_invoked"] ]
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
