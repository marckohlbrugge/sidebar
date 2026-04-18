class Turn::Persona::FactChecker < Turn::Persona::Base
  RESPONSES_ENDPOINT = URI("https://api.x.ai/v1/responses")

  self.display_name = "Gary"
  self.emoji = "📋"
  self.color = "blue"
  self.triggers = %w[FACT_CHECK]
  self.model = "grok-4.20-0309-reasoning"
  self.prompt = <<~PROMPT
    You are Gary Dell'Abate — a stern, detail-obsessed producer who keeps the show factually accurate. You were given a completed turn that contains a specific factual claim.

    You have access to a web_search tool. Use it only when the turn contains a verifiable specific: a number, date, named person or place, quoted statement, or concrete claim. For vague opinions, generalities, or obvious common knowledge, skip the search.

    Your job: in one or two crisp sentences, note whether the claim sounds correct, rough, or questionable, and cite the key detail your search turned up (or, if you didn't search, what you recall).

    Rules:
    - Under 40 words. No filler.
    - If the search doesn't produce anything useful, say so plainly ("Couldn't find a source that confirms this").
    - If there's nothing worth checking, return exactly: PASS
    - Never flatter. Never summarize the turn back.
  PROMPT

  def run!
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    response = post_responses_request

    @turn.stream_session.increment!(:llm_call_count)
    elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).to_i
    searches = response.fetch("output", []).count { |item| item["type"] == "web_search_call" }
    Rails.logger.info "[persona=#{self.class.key}] turn=#{@turn.id} latency=#{elapsed_ms}ms web_searches=#{searches}"

    body = extract_text(response).strip
    return if body.empty? || body == "PASS"

    @turn.comments.create!(
      personality: self.class.key,
      body: body,
      llm_model: self.class.model,
      grounded: searches.positive?
    )
  end

  private

  def post_responses_request
    req = Net::HTTP::Post.new(RESPONSES_ENDPOINT, {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{api_key}"
    })
    req.body = {
      model: self.class.model,
      instructions: self.class.prompt,
      input: [ { role: "user", content: user_message } ],
      tools: [ { type: "web_search" } ]
    }.to_json

    res = Net::HTTP.start(RESPONSES_ENDPOINT.hostname, RESPONSES_ENDPOINT.port, use_ssl: true) do |http|
      http.request(req)
    end
    JSON.parse(res.body)
  end

  def extract_text(response)
    response["output_text"].presence || response.fetch("output", [])
      .select { |item| item["type"] == "message" }
      .flat_map { |item| item["content"] || [] }
      .map { |chunk| chunk["text"] }
      .compact
      .join
  end

  def api_key
    ENV["XAI_API_KEY"].presence || Rails.application.credentials.xai_api_key
  end
end
