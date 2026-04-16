class StreamSession < ApplicationRecord
  STATUSES = %w[idle running stopped killed].freeze

  has_many :transcript_events, dependent: :destroy
  has_many :turns, dependent: :destroy

  validates :youtube_url, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :running, -> { where(status: "running") }

  def kill_switched?
    ENV["KILL_SWITCH"] == "1" || status == "killed"
  end

  def replay_origin
    @replay_origin ||= turns.minimum(:finalized_at)
  end

  def spawn_ingest!
    return if process_alive?
    resolve_video_id!
    file = Rails.root.join("log/ingest_#{id}.log")
    spawned = Process.spawn(
      { "RAILS_ENV" => Rails.env },
      Rails.root.join("bin/rails").to_s, "runner", "script/ingest.rb", id.to_s,
      in: "/dev/null", out: file.to_s, err: file.to_s, pgroup: true, chdir: Rails.root.to_s
    )
    Process.detach(spawned)
    update!(pid: spawned, log_path: file.to_s)
  end

  def resolve_video_id!
    return if video_id.present?
    id_out = `yt-dlp --get-id #{youtube_url.shellescape} 2>/dev/null`.strip.lines.first&.strip
    update!(video_id: id_out) if id_out.present?
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
end
