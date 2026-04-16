class StreamSession::Spawner
  def initialize(session)
    @session = session
  end

  def spawn!
    return if @session.process_alive?
    @session.resolve_video_id!
    @session.detect_kind!
    log_file = Rails.root.join("log/ingest_#{@session.id}.log")
    pid = Process.spawn(
      { "RAILS_ENV" => Rails.env },
      Rails.root.join("bin/rails").to_s, "runner", "script/ingest.rb", @session.id.to_s,
      in: "/dev/null", out: log_file.to_s, err: log_file.to_s, pgroup: true, chdir: Rails.root.to_s
    )
    Process.detach(pid)
    @session.update!(pid: pid, log_path: log_file.to_s)
  end

  def stop!
    Process.kill("TERM", -@session.pid) if @session.pid && @session.process_alive?
    @session.update!(pid: nil)
  rescue Errno::ESRCH
    @session.update!(pid: nil)
  end
end
