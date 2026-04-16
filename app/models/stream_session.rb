class StreamSession < ApplicationRecord
  has_many :transcript_events, dependent: :destroy
  has_many :turns, dependent: :destroy

  has_secure_token

  enum :status, { idle: "idle", running: "running", stopped: "stopped", killed: "killed" }, default: :idle, validate: true

  validates :youtube_url, presence: true

  def to_param
    token
  end

  scope :demos, -> { where(demo: true).order(created_at: :desc) }

  def self.kill_switched?
    ENV["KILL_SWITCH"] == "1"
  end

  def replay_origin
    @replay_origin ||= turns.minimum(:finalized_at)
  end

  def timeline_turns
    turns.ordered.includes(:gate_decision, :comments)
  end

  def spawn_ingest!
    Spawner.new(self).spawn!
  end

  def stop_ingest!
    Spawner.new(self).stop!
  end

  def process_alive?
    return false unless pid
    Process.getpgid(pid)
    true
  rescue Errno::ESRCH
    false
  end

  def resolve_video_id!
    return if video_id.present?
    resolved = YtDlp.video_id(youtube_url)
    update!(video_id: resolved) if resolved
  end

  def detect_kind!
    update!(live: YtDlp.live?(youtube_url))
  end
end
