class StreamSession < ApplicationRecord
  has_many :transcript_events, dependent: :destroy
  has_many :turns, dependent: :destroy

  has_secure_token

  enum :status, { idle: "idle", running: "running", stopped: "stopped", killed: "killed" }, default: :idle, validate: true
  enum :source_kind, { url: "url", microphone: "microphone" }, default: :url, validate: true, prefix: :source

  validates :youtube_url, presence: true, if: :source_url?

  def to_param
    token
  end

  def self.kill_switched?
    ENV["KILL_SWITCH"] == "1"
  end

  def replay_origin
    @replay_origin ||= turns.minimum(:finalized_at)
  end

  def show_video?
    # Pre-recorded videos replay in sync with the transcript; live
    # streams replay with a mismatched current-broadcast feed, so we
    # only embed them while actively ingesting.
    video_id.present? && (!live? || running?)
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
end
