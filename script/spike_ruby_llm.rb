class GateDecisionSchema < RubyLLM::Schema
  string :action, enum: %w[WAIT IGNORE COMMENT FACT_CHECK]
  string :reason
end

sample_turn = "So the unemployment rate in the US dropped to 3.8 percent last month, which is the lowest it's been since 1969."

system_prompt = <<~PROMPT
  You are a gatekeeper for a live-stream commentary system. Given a completed speaker turn, classify it into one of:
  - WAIT: speaker didn't finish a thought
  - IGNORE: not worth reacting to
  - COMMENT: worth a brief commentary
  - FACT_CHECK: contains a verifiable factual claim
PROMPT

response = RubyLLM.chat(model: "grok-4-1-fast-non-reasoning")
  .with_instructions(system_prompt)
  .with_schema(GateDecisionSchema.new)
  .ask(sample_turn)

puts "Turn: #{sample_turn}"
puts "---"
pp response.content
