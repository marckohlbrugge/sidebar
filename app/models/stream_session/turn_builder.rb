class StreamSession::TurnBuilder
  MIN_WORDS_PER_TURN = 8
  MAX_WORDS_PER_TURN = 80

  def initialize(session)
    @session = session
    @buffer = []
    @started_at = nil
    @audio_start_ms = nil
    @audio_end_ms = nil
  end

  def handle(raw)
    data = JSON.parse(raw)
    ActiveRecord::Base.connection_pool.with_connection do
      TranscriptEvent.from_deepgram(@session, data)
      advance(data)
    end
  rescue JSON::ParserError
    nil
  end

  private

  def advance(data)
    text = data.dig("channel", "alternatives", 0, "transcript").to_s
    return if text.empty?

    if data["is_final"]
      @buffer << text
      @started_at ||= Time.current
      @audio_start_ms ||= ((data["start"] || 0) * 1000).to_i
      @audio_end_ms = (((data["start"] || 0) + (data["duration"] || 0)) * 1000).to_i
    end

    return unless @buffer.any?
    close! if should_close?(data)
  end

  def should_close?(data)
    word_count = @buffer.join(" ").split.size
    return true if word_count >= MAX_WORDS_PER_TURN
    data["speech_final"] && word_count >= MIN_WORDS_PER_TURN
  end

  def close!
    @session.turns.create!(
      text: @buffer.join(" "),
      started_at: @started_at,
      ended_at: Time.current,
      finalized_at: Time.current,
      audio_start_ms: @audio_start_ms,
      audio_end_ms: @audio_end_ms
    )
    @buffer = []
    @started_at = nil
    @audio_start_ms = nil
    @audio_end_ms = nil
  end
end
