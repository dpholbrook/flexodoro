require 'sinatra'
require 'tilt/erubis'
require 'yaml'
require 'bcrypt'
require 'redcarpet'

require_relative 'user'
require_relative 'cycle'
require_relative 'database_persistence'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

configure(:development) do
  require "sinatra/reloader"
  require "pry"
  also_reload "database_persistence.rb"
  also_reload "user.rb"
  also_reload "cycle.rb"
  also_reload "style.css"
end

configure do
  set :erb, :escape_html => true
end

before do
  session[:rest_reserves] ||= 0
  session[:time_zone] ||= 0
  session[:username] ||= 'guest'
  session[:user_id] ||= 0
  @user = User.new
  @storage = DatabasePersistence.new
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
  cycle = session[:current_cycle]

  cycle.focus_start + SECONDS_PER_POMODORO + focus_deficit + cycle.total_pauses
end

def rest_reserves_remaining?
  next_suggested_focus > session[:current_cycle].rest_start
end

def next_suggested_focus
  cycle = session[:current_cycle]

  cycle.rest_start + session[:rest_reserves] + cycle.total_pauses
end

def next_focus
  cycle = session[:current_cycle]

  if rest_reserves_remaining?
    "Focus suggested at: #{stringify(next_suggested_focus)}"
  else
    'Rest not recommended. You have no rest reserves.'
  end
end

def reset_tracker
  session[:focus] = false
  session[:rest_reserves] = 0
  session.delete(:current_cycle)
end

# def render_markdown(text)
#   markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
#   markdown.render(text)
# end

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

  if session[:pause]
    erb :pause
  elsif focus_mode?
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
    @user.invalid_sign_up_message(username, password, time_zone)
  if invalid_sign_up_message
    session[:message] = invalid_sign_up_message
    status 422

    @utc = Time.now
    erb :sign_up
  else
    time_zone = time_zone.to_i

    @user.create_account(username, password, time_zone)
    session[:message] = 'Account successfully created.'

    redirect '/sign_in'
  end
end

post '/sign_in' do
  username = params[:username]
  password = params[:password]

  user = @user.valid_user(username, password)

  if user
    session[:username] = user[:username]
    session[:time_zone] = user[:time_zone].to_i
    session[:user_id] = user[:id].to_i

    redirect '/'
  else
    session[:message] = 'Invalid username or password.'
    status 422
    erb :sign_in
  end
end

get '/sign_out' do
  session.delete(:username)
  session.delete(:user_id)
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
    @storage.log(cycle, session[:user_id])
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
  @dates_and_durations = @storage.dates_and_durations(session[:user_id])

  erb :log
end

get '/log/:date' do
  @date = params[:date]
  @data_for_date = @storage.data_for_date(session[:user_id], @date)
  @total_duration_for_date = @storage.total_duration_for_date(@date, session[:user_id])

  erb :date
end

get '/about' do
  erb :about
end

post '/reset' do
  reset_tracker

  redirect '/'
end

post '/pause' do
  session[:pause] = true
  session[:current_cycle].start_pause

  redirect '/tracker'
end

post '/unpause' do
  session[:pause] = false
  session[:current_cycle].log_pause

  redirect '/tracker'
end

not_found do
  redirect '/'
end
