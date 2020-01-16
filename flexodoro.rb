require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for" # Do I need this?
require "tilt/erubis"
require "yaml"

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

# def set_session_start_time
#   return unless session[:focus_start_time]
#   session[:session_start_time] = session[:focus_start_time]
# end

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

# def generate_date
#   session[:focus_start_time].strftime("%d/%m/%Y")
# end

def update_data
  if ENV["RACK_ENV"] == "test"
    data = []
  else
    data = if YAML.load(File.read("data/user_data.yml"))
      YAML.load(File.read("data/user_data.yml"))
    else
      []
    end
  end

  cycle = generate_cycle
  data << cycle
end

def write_data(data)
  if ENV["RACK_ENV"] == "test"
    File.open("test/data/user_data.yml", "w") { |file| file.write(data.to_yaml) }
  else
    File.open("data/user_data.yml", "w") { |file| file.write(data.to_yaml) }
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

get "/" do
  erb :home
end

post "/focus" do
  if end_of_cycle?
    set_rest_end_time
    write_data(update_data)
    session[:focus_start_time] = session[:rest_end_time]
    session[:elapsed_time_rested] = calculate_time_rested
    decrement_accumulated_rest_time
  else
    set_focus_start_time
  end

  redirect "/focus"
end

get "/focus" do

  @focus_start_time = format_time_object(session[:focus_start_time])
  @suggested_rest_time = format_time_object(calculate_suggested_rest_time)
  @data = YAML.load(File.read("data/user_data.yml"))
  # @accumulated_rest_time = format_seconds(session[:accumulated_rest_time])
  erb :focus
end

post "/rest" do
  set_rest_start_time
  calculate_elapsed_time_focused
  calculate_new_rest_time
  incriment_accumulated_rest_time
  redirect "/rest"
end

get "/rest" do
  @rest_mode_start_time = format_time_object(session[:rest_start_time])
  session[:next_suggested_focus_mode] = session[:rest_start_time] + session[:accumulated_rest_time]
  @next_suggested_focus_message = calculate_next_suggested_focus_session
  # @accumulated_rest_time = format_seconds(session[:accumulated_rest_time])

  erb :rest
end

post "/reset" do
  session[:accumulated_rest_time] = 0
  session[:focus_start_time] = nil
  session[:rest_start_time] = nil
  session[:elapsed_time_rested] = 0
  session[:elapsed_time_focused] = 0

  redirect "/"
end

def generate_date_list(data)
  @list = []

  data.each do |cycle|
    date = cycle[:focus_start_time].strftime("%d-%m-%Y")
    @list << date unless @list.include?(date)
  end

  @list
end

get "/log" do
  @data = YAML.load(File.read("data/user_data.yml"))

  erb :log
end

def return_cycles_from_date(data, date)
  data.select do |cycle|
    cycle[:focus_start_time].strftime("%d/%m/%Y") == date
  end
end

get "/log/:date" do
  @date = params[:date].gsub('-', '/')
  data = YAML.load(File.read("data/user_data.yml"))
  @data = return_cycles_from_date(data, @date)

  erb :date
end

=begin

write tests for log

when you go to log, where do you go from there? if you were in focus mode, you

main navigation would be nice, but if you are in focus mode, you shouldn't be able to go to focus mode

total time for each day


User clicks focus button
New rest time is added to existing rest time and saved
Starts focus timer
Button turns into Rest button

home page
  - displays home page view
    - focus button

focus button
  - user posts focus request
  - user is redirected to '/focus' route

focus route
  - creates focus start time and stores in session
  - creates suggested rest time

  - displays focus view template
    - start time
    - suggested rest time
      - displays rest button

rest button
  - sends post request to '/rest'

post '/rest' route
  - redirects to get 'rest' route

get '/rest' route
  - records current time (when focus mode was stopped)
  - retrieves the start time of the last focus session
  - the difference is the focus duration
  - focus duration / 5 is rest accumulated
  - total rest is new rest time plus existing rest time
  - displays rest view template
    - displays the last focus time and new rest time
    - displays total rest time accumulated

reset button
  - post request '/reset'
    - clears session
    - redirects home

layout
  - reset button
  - log of each focus session

  - Calculating focus time
    - focus post request sets start time
    - rest post request sets rest_start_time
    - subtract the two for total focused time to be logged
      - returns weird time
      - use total focused time to calculate banked rest time

  - Count down rest time
    - when rest button is clicked, rest time starts
    - when focus button is clicked, focus time starts
    - subtract those two to determine amount of time rested
    - subtract that amount from accumulated rest time
      - ensure that negative number works

  - Convert seconds to hours, minutes, seconds

  - if rest reserves is in negative numbers,
    - adjust suggested rest time to study until 5 minutes of rest gained

  - in rest mode
    - if next suggested foucus time is before rest start time
      - then output text "Resting is not reccommended. You have no rest reserves."

      - Log sessions
        - session number
        - focus mode session
        - rest mode session
        - total time

        - grand total time

        - session is created when rest button is clicked

        - focus session
          - focus start time
          - focus end time/ rest start time

        - rest session
          - rest start time
          - rest end time/ focus start time

        - total time is focus time + rest time + rest reserves if reserves are negative

        session: { session_1: {
                              focus_start_time: x,
                              rest_start_time: y,
                              next_session_focus_start_time: z,
                              total_time: q
                              }}

        session: { session_1: {
                              focus_start_time: x,
                              rest_start_time: y,
                              next_session_focus_start_time: z,
                              total_time: q
                              }}

                              {
  users: {
    drew: {
      1 / 12 / 20: {
        session_1: {
          focus_start: 'x',
          rest_start: 'y',
          total_time: 'z'
        }
        session_2: {
        }
      }
    }
  }
}

      - users
        - each has their own file or one big file with all user data?


        - write data to user file
          - when focus clicked for second time
            - write new session data to yaml file:
              user_data[:current_date][session][focus_start:] = x


        -  read user data in log
          - create object form yaml file
            - for each date
              - for each session
                - print out study start and stop time and duration

            {
              1 / 12 / 20: {
                session_1: {
                  focus_start: 'x',
                  rest_start: 'y',
                  total_time: 'z'
                }
                session_2: {
                }
              }

    log session
      - session[:data][:date][:session_number][:focus_start] = session[:focus_start]
      -

      log cycle
        - data = {
                   1/12/20: [
                              { focus_start: time, rest_start: time, rest_end: time },
                              { focus_start: time, rest_start: time, rest_end: time }
                            ]
                 }
        - date is the date of the start time
        - cycle = {focus_start, rest_start, rest_end}
        - data[date] << cycle

  - create log route
    - route displays the parsed user data from yaml file
    - create route for log
    - display parsed data from yaml file
      - create data object from yaml file
        - for each cycle hash
          - start time is formatted start time
          - break time
          - break end time
          - total cycle time
      -

      for each date that exists, create a link
      links to rout for that date

      date route
        - set date from params
        - set data from yaml
          - return cycles from that date
            - iterate on data
            - select any hash that includes that date
        - goes to date view template

      date view template



=end
