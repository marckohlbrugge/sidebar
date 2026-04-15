class Turn::Persona::Base
  MODEL = "claude-sonnet-4-5"
  CONTEXT_TURNS = 5
  RECENT_COMMENTS = 3

  class << self
    def triggered_by?(action)
      triggers.include?(action)
    end

    def all
      [ Turn::Persona::FactChecker, Turn::Persona::Context, Turn::Persona::Comedy, Turn::Persona::Troll ]
    end

    def find(key)
      all.find { |p| p.key == key }
    end

    # Subclasses override these:
    def key = name.demodulize.underscore
    def display_name = raise NotImplementedError
    def emoji = raise NotImplementedError
    def color = "gray"
    def prompt = raise NotImplementedError
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
      .where("id < ?", @turn.id)
      .order(id: :desc)
      .limit(self.class::CONTEXT_TURNS)
      .pluck(:text)
      .reverse

    recent_comments = Comment
      .joins(:turn)
      .where(turns: { stream_session_id: @turn.stream_session_id })
      .where(personality: self.class.key)
      .order(id: :desc)
      .limit(self.class::RECENT_COMMENTS)
      .pluck(:body)
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
