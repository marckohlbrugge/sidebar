class Turn::Persona::Base
  CONTEXT_TURNS = 5
  RECENT_COMMENTS = 3

  class_attribute :display_name, :emoji, :color, :triggers, :prompt, :model
  self.color = "gray"
  self.triggers = %w[COMMENT].freeze
  self.model = "grok-4.20-0309-non-reasoning"

  class << self
    def key = name.demodulize.underscore
    def triggered_by?(action) = triggers.include?(action)
  end

  def initialize(turn)
    @turn = turn
  end

  def run!
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = RubyLLM.chat(model: self.class.model)
      .with_instructions(self.class.prompt)
      .ask(user_message)

    @turn.stream_session.increment!(:llm_call_count)
    elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).to_i
    Rails.logger.info "[persona=#{self.class.key}] turn=#{@turn.id} latency=#{elapsed_ms}ms"

    body = result.content.to_s.strip
    return if pass?(body)

    @turn.comments.create!(
      personality: self.class.key,
      body: body,
      llm_model: self.class.model
    )
  end

  protected

  # True for empty bodies or any variation of "PASS" the LLM might emit:
  # "PASS", "Pass", "**PASS**", "PASS.", " pass! ", etc.
  def pass?(body)
    body.blank? || body.gsub(/\W+/, "").casecmp?("pass")
  end

  def user_message
    previous_turns = @turn.stream_session.turns
      .where(id: ...@turn.id)
      .order(:id)
      .last(CONTEXT_TURNS)
      .pluck(:text)

    recent_comments = @turn.stream_session.turns
      .joins(:comments)
      .where(comments: { personality: self.class.key })
      .where(id: ...@turn.id)
      .order("comments.id DESC")
      .limit(RECENT_COMMENTS)
      .pluck("comments.body")
      .reverse

    <<~MSG
      Previous turns (oldest to newest):
      #{previous_turns.map { |t| "- #{t}" }.join("\n").presence || "(none)"}

      Your recent remarks (do not repeat these or their structure):
      #{recent_comments.map { |c| "- #{c}" }.join("\n").presence || "(none)"}

      Current turn to react to:
      #{@turn.text}
    MSG
  end
end
