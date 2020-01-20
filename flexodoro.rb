require "sinatra"
require "sinatra/reloader" if development?
# require "sinatra/content_for" # Do I need this?
require "tilt/erubis"
require "yaml"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:elapsed_time_focused] ||= 0
  session[:elapsed_time_rested] ||= 0
  session[:accumulated_rest_time] ||= 0
end

SECONDS_PER_POMODORO = 1500

def format_time_object(time)
  time.strftime("%I:%M:%S %p")
end

def format_seconds(seconds)
  sprintf("%d", seconds)
end

def calculate_elapsed_time_focused
  session[:elapsed_time_focused] = session[:rest_start_time] - session[:focus_start_time]
end

def calculate_new_rest_time
  session[:new_rest_time_earned] = session[:elapsed_time_focused] / 5
end

def incriment_accumulated_rest_time
  session[:accumulated_rest_time] += session[:new_rest_time_earned]
end

def decrement_accumulated_rest_time
  session[:accumulated_rest_time] -= session[:elapsed_time_rested]
end

def calculate_time_rested
  session[:elapsed_time_rested] = session[:focus_start_time] - session[:rest_start_time]
end

def calculate_suggested_rest_time
  if session[:accumulated_rest_time] < 0
    focus_deficit = ((session[:accumulated_rest_time]) * (-5))
    session[:focus_start_time] + SECONDS_PER_POMODORO + focus_deficit
  else
    session[:focus_start_time] + SECONDS_PER_POMODORO
  end
end

def set_focus_start_time
  if ENV["RACK_ENV"] == "test"
    session[:focus_start_time] = Time.new(2020, 1, 12, 8, 0, 0)
  else
    session[:focus_start_time] = Time.new
  end
end

def set_rest_start_time
  if ENV["RACK_ENV"] == "test"
    session[:rest_start_time] = Time.new(2020, 1, 12, 8, 25, 0)
  else
    session[:rest_start_time] = Time.new
  end
end

def set_rest_end_time
  if ENV["RACK_ENV"] == "test"
    session[:rest_end_time] = Time.new(2020, 1, 12, 8, 0, 0)
  else
    session[:rest_end_time] = Time.new
  end
end

def rest_reserves_remaining?
  session[:next_suggested_focus_mode] > session[:rest_start_time]
end

def calculate_next_suggested_focus_session
  if rest_reserves_remaining?
    "Focus at: #{format_time_object(session[:next_suggested_focus_mode])}"
  else
    "Rest not recommended. You have no rest reserves."
  end
end

def set_session_end_time
  session[:session_end_time] = session[:focus_start_time]
end

def end_of_cycle?
  session[:rest_start_time]
end

def generate_cycle
  {
    focus_start_time: session[:focus_start_time],
    rest_start_time: session[:rest_start_time],
    rest_end_time: session[:rest_end_time]
  }
end

def load_cycle_data
  if ENV["RACK_ENV"] == "test"
    YAML.load(File.read("test/data/user_data.yml"))
  elsif YAML.load(File.read("data/user_data.yml"))
    YAML.load(File.read("data/user_data.yml"))
  else
    []
  end
end

def write_data(data)
  if ENV["RACK_ENV"] == "test"
    File.open("test/data/user_data.yml", "w") { |file| file.write(data.to_yaml) }
  else
    File.open("data/user_data.yml", "w") { |file| file.write(data.to_yaml) }
  end
end

def log_cycle
  data = load_cycle_data
  cycle = generate_cycle
  data << cycle
  write_data(data)
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def generate_date_list(data)
  @list = []

  data.each do |cycle|
    date = cycle[:focus_start_time].strftime("%d-%m-%Y")
    @list << date unless @list.include?(date)
  end

  @list
end

def load_user_data
  if ENV["RACK_ENV"] == "test"
    YAML.load(File.read("test/data/user_data.yml"))
  else
    YAML.load(File.read("data/user_data.yml"))
  end
end

def return_cycles_from_date(data, date)
  data.select do |cycle|
    cycle[:focus_start_time].strftime("%d/%m/%Y") == date
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
    YAML.load_file(credentials_path)
end

def valid_credentials?(given_username, given_password)
  credentials = load_user_credentials

  if credentials.key?(given_username)
    stored_password_hash = credentials[given_username]
    BCrypt::Password.new(stored_password_hash) == given_password
  else
    false
  end
end

def load_users
  if ENV["RACK_ENV"] == "test"
    YAML.load(File.read("test/data/users.yml"))
  elsif YAML.load(File.read("users.yml"))
    YAML.load(File.read("users.yml"))
  else
    {}
  end
end

def write_to_users(data)
  if ENV["RACK_ENV"] == "test"
    File.open("test/data/users.yml", "w") { |file| file.write(data.to_yaml) }
  else
    File.open("users.yml", "w") { |file| file.write(data.to_yaml) }
  end
end

def unique?(username, data)
  !data.include?(username)
end

get "/" do
  if !session[:focus] && !end_of_cycle?
     erb :home
  elsif session[:focus] == true
    @focus_start_time = format_time_object(session[:focus_start_time])
    @suggested_rest_time = format_time_object(calculate_suggested_rest_time)
    # @data = YAML.load(File.read("data/user_data.yml"))
    # @accumulated_rest_time = format_seconds(session[:accumulated_rest_time])
    erb :focus
    # "#{session[:focus]}"
  else
    @rest_mode_start_time = format_time_object(session[:rest_start_time])
    session[:next_suggested_focus_mode] = session[:rest_start_time] + session[:accumulated_rest_time]
    @next_suggested_focus_message = calculate_next_suggested_focus_session
    # @accumulated_rest_time = format_seconds(session[:accumulated_rest_time])

    erb :rest
  end
end

post "/focus" do
  session[:focus] = true

  if end_of_cycle?
    set_rest_end_time
    log_cycle
    session[:focus_start_time] = session[:rest_end_time]
    session[:elapsed_time_rested] = calculate_time_rested
    decrement_accumulated_rest_time
  else
    set_focus_start_time
  end

  redirect "/"
end

post "/rest" do
  session[:focus] = false

  set_rest_start_time
  calculate_elapsed_time_focused
  calculate_new_rest_time
  incriment_accumulated_rest_time
  redirect "/"
end

get "/log" do
  @data = load_user_data

  erb :log
end

get "/log/:date" do
  @date = params[:date].gsub('-', '/')
  data = load_user_data
  @data = return_cycles_from_date(data, @date)

  erb :date
end

post "/reset" do
  session[:focus] = false
  session[:accumulated_rest_time] = 0
  session[:focus_start_time] = nil
  session[:rest_start_time] = nil
  session[:elapsed_time_rested] = 0
  session[:elapsed_time_focused] = 0

  redirect "/"
end

get "/sign_in" do
  erb :sign_in
end

post "/sign_in" do
  credentials = load_user_credentials
  username = params[:username]
  password = params[:password]

  if valid_credentials?(username, password)
    session[:username] = username
    redirect "/" # redirect produces a 302 Found status code
  else
    session[:message] = "Invalid Credentials."
    status 422 # Unprocessable Entity
    erb :sign_in
  end
end

get "/sign_out" do
  session.delete(:username)

  redirect "/"
end

get "/sign_up" do
  erb :sign_up
end

post "/sign_up" do
  username = params[:username]
  password = BCrypt::Password.create(params[:password]).to_s
  data = load_users

  if unique?(username, data)
    data[username] = password
    write_to_users(data)
    session[:message] = "Account successfully created."
    redirect "/sign_in"
  else
    status 422
    session[:message] = "That username is already taken."
    erb :sign_up
  end
end
