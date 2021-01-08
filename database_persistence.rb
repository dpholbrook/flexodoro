require "pg"

class DatabasePersistence
  def initialize
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "flexodoro")
          end
  end

  def disconnect
    @db.close
  end

  def query(statement, *params)
    # @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def load_user_credentials
    result = query("SELECT * FROM users")
    result.map do |tuple|
      { id: tuple["id"],
        username: tuple["username"],
        password: tuple["password"],
        time_zone: tuple["time_zone"] }
    end
  end

  def create_account(username, password, time_zone)
    sql = "INSERT INTO users (username, password, time_zone) VALUES ($1, $2, $3)"
    query(sql, username, password, time_zone)
  end

  def log(cycle, user_id)
    cycle_data = cycle.data

    sql = <<~SQL
      INSERT INTO cycles (user_id, focus_start, rest_start, rest_end, duration)
      VALUES ($1, $2, $3, $4, $5)
    SQL
    query(
      sql,
      user_id,
      cycle_data[:focus_start],
      cycle_data[:rest_start],
      cycle_data[:rest_end],
      cycle_data[:duration]
    )
  end

  def dates_and_durations(user_id)
    sql = <<~SQL
      SELECT focus_start::date AS date, sum(duration) AS duration
      FROM cycles
      WHERE user_id = $1
      GROUP BY focus_start::date;
    SQL

    result = query(sql, user_id)

    result.map do |tuple|
      { date: tuple["date"], duration: tuple["duration"].to_i }
    end
  end

  def total_duration_for_date(date, user_id)
    this = dates_and_durations(user_id).select do |instance|
      instance[:date] == date
    end
    this.first[:duration]
  end

  def data_for_date(user_id, date)
    sql = <<~SQL
    SELECT focus_start::time, rest_start::time, rest_end::time, duration
    From cycles
    WHERE user_id = $1
    AND focus_start::date = $2;
    SQL

    result = query(sql, user_id, date)

    result.map do |tuple|
      { date: date,
        focus_start: tuple["focus_start"],
        rest_start: tuple["rest_start"],
        rest_end: tuple["rest_end"],
        duration: tuple["duration"].to_i }
    end
  end

end
