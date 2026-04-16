class StreamSession < ApplicationRecord
  has_many :transcript_events, dependent: :destroy
  has_many :turns, dependent: :destroy

  enum :status, { idle: "idle", running: "running", stopped: "stopped", killed: "killed" }, default: :idle, validate: true

  validates :youtube_url, presence: true

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
    return if process_alive?
    resolve_video_id!
    log_file = Rails.root.join("log/ingest_#{id}.log")
    spawned = Process.spawn(
      { "RAILS_ENV" => Rails.env },
      Rails.root.join("bin/rails").to_s, "runner", "script/ingest.rb", id.to_s,
      in: "/dev/null", out: log_file.to_s, err: log_file.to_s, pgroup: true, chdir: Rails.root.to_s
    )
    Process.detach(spawned)
    update!(pid: spawned, log_path: log_file.to_s)
  end

  def stop_ingest!
    Process.kill("TERM", -pid) if pid && process_alive?
    update!(pid: nil)
  rescue Errno::ESRCH
    update!(pid: nil)
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
    resolved = `yt-dlp --get-id #{youtube_url.shellescape} 2>/dev/null`.strip.lines.first&.strip
    update!(video_id: resolved) if resolved.present?
  end
end
