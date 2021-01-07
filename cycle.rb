# state and logic for each current flexodoro cycle
class Cycle
  attr_reader :focus_start, :rest_start, :rest_duration, :focus_duration,
              :rest_end

  def initialize(time_zone)
    @time_zone_offset = time_zone * SECONDS_PER_HOUR
    @focus_start = set_time
    @pauses = []
  end

  def set_time
    Time.new + @time_zone_offset
  end

  def calculate_rest_duration
    @rest_duration = (@rest_end - @rest_start) - total_pauses
  end

  def calculate_focus_duration
    @focus_duration = (@rest_start - @focus_start) - total_pauses
  end

  def rest_time_earned
    @focus_duration / 5
  end

  def total_duration
    @total_duration = @rest_end - @focus_start - total_pauses
  end

  def data
    {
      focus_start: @focus_start,
      rest_start: @rest_start,
      rest_end: @rest_end,
      duration: total_duration
    }
  end

  def date
    @focus_start.strftime('%Y-%m-%d')
  end

  def set_rest_start
    @rest_start =
      if ENV['RACK_ENV'] == 'test'
        Time.new(2020, 1, 12, 8, 25, 0)
      else
        set_time
      end
  end

  def set_rest_end
    @rest_end =
      if ENV['RACK_ENV'] == 'test'
        Time.new(2020, 1, 12, 8, 30, 0)
      else
        set_time
      end
  end

  def test_cycle
    @focus_start = Time.new(2020, 1, 12, 8, 0, 0) + @time_zone_offset
    @rest_start = Time.new(2020, 1, 12, 8, 25, 0) + @time_zone_offset
    @rest_end = Time.new(2020, 1, 12, 8, 30, 0) + @time_zone_offset
    calculate_rest_duration
    self
  end

  def start_pause
    @pause_start = set_time
  end

  def stop_pause
    @pause_stop = set_time
  end

  def log_pause
    stop_pause
    @pauses << (@pause_stop - @pause_start)
  end

  def total_pauses
    @pauses.sum
  end
end
