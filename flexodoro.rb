require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "yaml"
require "bcrypt"
require "redcarpet"
require "pry" if development?

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

def formatted_duration(total_seconds)
  hours = total_seconds / (60 * 60)
  minutes = (total_seconds / 60) % 60
  seconds = total_seconds % 60

  sprintf("%02d:%02d:%02d", hours, minutes, seconds)
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

def set_time(at)
  if ENV["RACK_ENV"] == "test"
    case at
    when "focus start" then session[:focus_start_time] = Time.new(2020, 1, 12, 8, 0, 0)
    when "rest start" then session[:rest_start_time] = Time.new(2020, 1, 12, 8, 25, 0)
    when "rest end" then session[:rest_end_time] = Time.new(2020, 1, 12, 8, 0, 0)
    end
  else
    case at
    when "focus start" then session[:focus_start_time] = Time.new
    when "rest start" then session[:rest_start_time] = Time.new
    when "rest end" then session[:rest_end_time] = Time.new
    end
  end
end

# def set_focus_start_time
#   if ENV["RACK_ENV"] == "test"
#     session[:focus_start_time] = Time.new(2020, 1, 12, 8, 0, 0)
#   else
#     session[:focus_start_time] = Time.new
#   end
# end
#
# def set_rest_start_time
#   if ENV["RACK_ENV"] == "test"
#     session[:rest_start_time] = Time.new(2020, 1, 12, 8, 25, 0)
#   else
#     session[:rest_start_time] = Time.new
#   end
# end
#
# def set_rest_end_time
#   if ENV["RACK_ENV"] == "test"
#     session[:rest_end_time] = Time.new(2020, 1, 12, 8, 0, 0)
#   else
#     session[:rest_end_time] = Time.new
#   end
# end

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

# def set_session_end_time
#   session[:session_end_time] = session[:focus_start_time]
# end

def end_of_cycle?
  session[:rest_start_time]
end

def calculate_cycle_duration
  session[:rest_end_time] - session[:focus_start_time]
end

def generate_cycle
  {
    focus_start_time: session[:focus_start_time],
    rest_start_time: session[:rest_start_time],
    rest_end_time: session[:rest_end_time],
    cycle_duration: calculate_cycle_duration
  }
end

def load_cycle_data
  user = session[:username]

  if ENV["RACK_ENV"] == "test"
    YAML.load(File.read("test/data/user_data.yml"))
  elsif File.exist?("data/#{user}_data.yml")
    YAML.load(File.read("data/#{user}_data.yml"))
  else
    []
  end
end

def write_data(data)
  user = session[:username]

  if ENV["RACK_ENV"] == "test"
    File.open("test/data/user_data.yml", "w") { |file| file.write(data.to_yaml) }
  else
    File.open("data/#{user}_data.yml", "w") { |file| file.write(data.to_yaml) }
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

def total_time_for_date(data, date)
  cycles = return_cycles_from_date(data, date)

  totals = []

  cycles.each do |cycle|
    totals << cycle[:cycle_duration]
  end

  formatted_duration(totals.sum)
end

def generate_date_list(data)
  @list = {}

  data.each do |cycle|
    date = cycle[:focus_start_time].strftime("%m-%d-%Y")
    @list[date] = total_time_for_date(data, date) unless @list.include?(date)
  end

  @list
end

def load_user_data
  user = session[:username]

  if ENV["RACK_ENV"] == "test"
    YAML.load(File.read("test/data/user_data.yml"))
  elsif File.exist?("data/#{user}_data.yml")
    YAML.load(File.read("data/#{user}_data.yml"))
  else
    []
  end
end

def return_cycles_from_date(data, date)
  data.select do |cycle|
    cycle[:focus_start_time].strftime("%m-%d-%Y") == date
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

def reset_timer
  session[:focus] = false
  session[:accumulated_rest_time] = 0
  session[:focus_start_time] = nil
  session[:rest_start_time] = nil
  session[:elapsed_time_rested] = 0
  session[:elapsed_time_focused] = 0
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def invalid?(username, password)
  username.empty? || password.empty?
end

get "/" do
  if !session[:focus] && !end_of_cycle?

     erb :home
  elsif session[:focus] == true
    @focus_start_time = format_time_object(session[:focus_start_time])
    @suggested_rest_time = format_time_object(calculate_suggested_rest_time)

    erb :focus
  else
    @rest_mode_start_time = format_time_object(session[:rest_start_time])
    session[:next_suggested_focus_mode] = session[:rest_start_time] + session[:accumulated_rest_time]
    @next_suggested_focus_message = calculate_next_suggested_focus_session

    erb :rest
  end
end

post "/focus" do
  session[:focus] = true

  if end_of_cycle?
    set_time("rest end")
    log_cycle
    session[:focus_start_time] = session[:rest_end_time]
    session[:elapsed_time_rested] = calculate_time_rested
    decrement_accumulated_rest_time
  else
    set_time("focus start")
  end

  redirect "/"
end

post "/rest" do
  session[:focus] = false

  set_time("rest start")
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
  @date = params[:date]
  data = load_user_data
  @total = total_time_for_date(data, @date)
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
    reset_timer
    redirect "/" # redirect produces a 302 Found status code
  else
    session[:message] = "Invalid Credentials."
    status 422 # Unprocessable Entity
    erb :sign_in
  end
end

get "/sign_out" do
  session.delete(:username)
  reset_timer

  redirect "/"
end

get "/sign_up" do
  erb :sign_up
end

post "/sign_up" do
  username = params[:username]
  password = params[:password]
  data = load_users

  if invalid?(username, password)
    status 422
    session[:message] = "Please enter a username and password."

    erb :sign_up
  elsif unique?(username, data)
    password = BCrypt::Password.create(password).to_s
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

get "/about" do
  content = File.read("readme.md")
  erb render_markdown(content)
end
