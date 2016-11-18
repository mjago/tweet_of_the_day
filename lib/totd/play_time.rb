class PlayTime

  def initialize(dur)
    @duration = dur
    @start_time = Time.now
    update
  end

  def changed?
    ! unchanged?
  end

  def read
    store
    format_time
  end

  def ended?
    (@duration + 20) < @seconds
  end

  def unchanged?
    (update == stored) || paused?
  end

  def store
    @stored = @seconds
  end

  def stored
    @stored
  end

  def plural x
    x == 1 ? '' : 's'
  end

  def mins
    @seconds / 60
  end

  def secs
    @seconds % 60
  end

  def format x
    x < 10 ? '0' + x.to_s : x.to_s
  end

  def format_minutes
    format mins
  end

  def format_secs
    format secs
  end

  def format_remaining_time
    secs = @duration - @seconds
    format(secs/60) + ':' + format(secs%60)
  end

  def format_time
    ' (' + format_minutes + ':' + format_secs +
      ' / '  + format_remaining_time + ')'
  end

  def update
    @seconds = (Time.now - @start_time).to_i
  end

  def pause
    @paused = Time.now
  end

  def paused?
    @paused
  end

  def unpause
    @start_time = @start_time + (Time.now - @paused)
    @paused = false
  end

  def forward
    @start_time -= 1.5
  end

  def rewind
    @start_time += 1.5
  end
end
