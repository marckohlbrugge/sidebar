class Turn::Persona::Base
  MODEL = "claude-sonnet-4-5"
  CONTEXT_TURNS = 5
  RECENT_COMMENTS = 3

  class << self
    def key = name.demodulize.underscore
    def triggered_by?(action) = triggers.include?(action)
    def color = "gray"
    def triggers = %w[COMMENT]
  end

  def initialize(turn)
    @turn = turn
  end

  def run!
    result = RubyLLM.chat(model: self.class::MODEL)
      .with_instructions(self.class.prompt)
      .ask(user_message)

    @turn.stream_session.increment!(:llm_call_count)
    body = result.content.to_s.strip
    return if body.empty? || body == "PASS"

    @turn.comments.create!(
      personality: self.class.key,
      body: body,
      llm_model: self.class::MODEL
    )
  end

  private

  def user_message
    previous_turns = @turn.stream_session.turns
      .where(id: ...@turn.id)
      .order(:id)
      .last(self.class::CONTEXT_TURNS)
      .pluck(:text)

    recent_comments = @turn.stream_session.turns
      .joins(:comments)
      .where(comments: { personality: self.class.key })
      .where(id: ...@turn.id)
      .order("comments.id DESC")
      .limit(self.class::RECENT_COMMENTS)
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
