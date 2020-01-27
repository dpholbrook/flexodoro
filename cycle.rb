# state and logic for each current flexodoro cycle
class Cycle
  attr_reader :focus_start, :rest_start, :rest_duration, :focus_duration,
              :rest_end

  def initialize
    @focus_start = Time.new
  end

  def start_rest
    @rest_start = Time.new
  end

  def end_rest
    @rest_end = Time.new
  end

  def calculate_rest_duration
    @rest_duration = @rest_end - @rest_start
  end

  def calculate_focus_duration
    @focus_duration = @rest_start - @focus_start
  end

  def rest_time_earned
    @focus_duration / 5
  end

  def total_duration
    @total_duration = @rest_end - @focus_start
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
        Time.new
      end
  end

  def set_rest_end
    @rest_end =
      if ENV['RACK_ENV'] == 'test'
        Time.new(2020, 1, 12, 8, 30, 0)
      else
        Time.new
      end
  end

  def test_cycle
    @focus_start = Time.new(2020, 1, 12, 8, 0, 0)
    @rest_start = Time.new(2020, 1, 12, 8, 25, 0)
    @rest_end = Time.new(2020, 1, 12, 8, 30, 0)
    calculate_rest_duration
    self
  end
end
