require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'yaml'
require 'bcrypt'
require 'redcarpet'
require 'pry' if development?

require_relative 'user'
require_relative 'cycle'
require_relative 'data'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:rest_reserves] ||= 0
  session[:time_zone] ||= 0
  session[:username] ||= 'guest'
end

SECONDS_PER_POMODORO = 1500
TIME_ZONES = (-12..12)
SECONDS_PER_HOUR = 3600

helpers do
  def stringify(time)
    time.strftime('%I:%M:%S %p')
  end

  def round_to_minutes(time)
    time.strftime('(%m/%d) %I:%M %p')
  end

  def formatted(total_seconds)
    hours = total_seconds / (60 * 60)
    minutes = (total_seconds / 60) % 60
    seconds = total_seconds % 60

    format('%02d:%02d:%02d', hours, minutes, seconds)
  end

  def current_local_time(time_zone, utc)
    local_time = utc + (time_zone * SECONDS_PER_HOUR)
    round_to_minutes(local_time)
  end
end

def new_session?
  true unless session[:current_cycle]
end

def focus_mode?
  session[:focus]
end

def completing_current_cycle?
  session[:current_cycle]
end

def decrement_rest_reserves
  session[:rest_reserves] -= session[:current_cycle].rest_duration
end

def increment_rest_reserves
  if session[:rest_reserves]
    session[:rest_reserves] += session[:current_cycle].rest_time_earned
  else
    session[:rest_reserves] = session[:current_cycle].rest_time_earned
  end
end

def focus_deficit
  session[:rest_reserves] < 0 ? session[:rest_reserves] * -5 : 0
end

def suggested_rest_time
  session[:current_cycle].focus_start + SECONDS_PER_POMODORO + focus_deficit
end

def rest_reserves_remaining?
  next_suggested_focus =
    session[:current_cycle].rest_start + session[:rest_reserves]

  next_suggested_focus > session[:current_cycle].rest_start
end

def next_focus
  next_suggested_focus =
    session[:current_cycle].rest_start + session[:rest_reserves]

  if rest_reserves_remaining?
    "Focus at: #{stringify(next_suggested_focus)}"
  else
    'Rest not recommended. You have no rest reserves.'
  end
end

def reset_tracker
  session[:focus] = false
  session[:rest_reserves] = 0
  session.delete(:current_cycle)
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def data_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/data', __FILE__)
  else
    File.expand_path('../data', __FILE__)
  end
end

def new_cycle
  if ENV['RACK_ENV'] == 'test'
    Cycle.new(session[:time_zone]).test_cycle
  else
    Cycle.new(session[:time_zone])
  end
end

get '/' do
  reset_tracker

  erb :home
end

get '/tracker' do
  cycle = session[:current_cycle]
  redirect '/' unless cycle

  if focus_mode?
    @focus_start = cycle.focus_start
    @suggested_rest = suggested_rest_time

    erb :focus
  else
    @rest_start = cycle.rest_start
    @next_focus = next_focus

    erb :rest
  end
end

get '/sign_in' do
  erb :sign_in
end

get '/sign_up' do
  @utc = Time.now

  erb :sign_up
end

post '/sign_up' do
  username = params[:username]
  password = params[:password]
  time_zone = params[:time_zone]

  invalid_sign_up_message =
    User.invalid_sign_up_message(username, password, time_zone)
  if invalid_sign_up_message
    session[:message] = invalid_sign_up_message
    status 422

    @utc = Time.now
    erb :sign_up
  else
    time_zone = time_zone.to_i

    User.create_account(username, password, time_zone)
    session[:message] = 'Account successfully created.'

    redirect '/sign_in'
  end
end

post '/sign_in' do
  username = params[:username]
  password = params[:password]

  if User.valid_credentials?(username, password)
    session[:username] = username
    session[:time_zone] = User.time_zone(username)

    redirect '/'
  else
    session[:message] = 'Invalid Credentials.'
    status 422
    erb :sign_in
  end
end

get '/sign_out' do
  session.delete(:username)
  session[:time_zone] = 0

  redirect '/'
end

post '/focus' do
  session[:focus] = true
  cycle = session[:current_cycle]

  if completing_current_cycle?
    cycle.set_rest_end
    cycle.calculate_rest_duration
    decrement_rest_reserves
    Data.log(cycle, session[:username])
  end

  session[:current_cycle] = new_cycle

  redirect '/tracker'
end

post '/rest' do
  session[:focus] = false
  cycle = session[:current_cycle]

  cycle.set_rest_start
  cycle.calculate_focus_duration
  increment_rest_reserves

  redirect '/tracker'
end

get '/log' do
  data = Data.load_user_data(session[:username])
  @dates_and_durations = Data.dates_and_durations(data)

  erb :log
end

get '/log/:date' do
  @date = params[:date]
  @data_for_date = Data.load_user_data(session[:username])[@date]
  @total_duration_for_date = Data.total_duration_for_date(@data_for_date)

  erb :date
end

get '/about' do
  content = File.read('README.md')
  erb render_markdown(content)
end

post '/reset' do
  reset_tracker

  redirect '/'
end
