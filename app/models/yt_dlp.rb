module YtDlp
  def self.video_id(url)
    first_line `yt-dlp --get-id #{url.shellescape} 2>/dev/null`
  end

  def self.stream_url(url)
    first_line `yt-dlp -f "ba*/b" -g #{url.shellescape} 2>/dev/null`
  end

  def self.first_line(output)
    output.strip.lines.first&.strip.presence
  end
end
