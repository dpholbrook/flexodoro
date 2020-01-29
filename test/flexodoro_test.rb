ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'pry'
require 'fileutils'

require_relative '../flexodoro'

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_yaml_file(name, content = '')
    File.open(File.join(data_path, name), 'w') do |file|
      file.write(content)
    end
  end

  def yaml_file_content
    YAML.load(File.read('test/data/user_data.yml'))
  end

  def session
    last_request.env['rack.session']
  end

  def test_home
    get '/'

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(form action="/focus")
  end

  def test_first_focus_button_click
    post '/focus', {}, 'rack.session' => { time_zone: 0 }
    assert_equal 302, last_response.status
    assert_equal Time.new(2020, 1, 12, 8, 0, 0),
                 session[:current_cycle].focus_start
    assert_equal true, session[:focus]

    get last_response['Location']
    assert_includes last_response.body, 'Focus Mode'
  end

  def test_time_zone_offset
    post '/focus', {}, 'rack.session' => { time_zone: -7 }
    assert_equal 302, last_response.status
    assert_equal Time.new(2020, 1, 12, 1, 0, 0),
                 session[:current_cycle].focus_start
    assert_equal true, session[:focus]

    get last_response['Location']
    assert_includes last_response.body, 'Focus Mode'
  end

  def test_second_focus_button_click
    get '/', {}, 'rack.session' => { time_zone: 0 }

    create_yaml_file 'user_data.yml', '{}'

    post '/focus', {}, 'rack.session' => {
      time_zone: 0,
      current_cycle: new_cycle,
      rest_reserves: 300
    }
    assert_equal 302, last_response.status
    assert_equal Time.new(2020, 1, 12, 8, 30, 0),
                 session[:current_cycle].rest_end
    assert_equal 300, session[:current_cycle].rest_duration
    assert_equal 0, session[:rest_reserves]
    assert_equal true, session[:focus]

    get last_response['Location']
    assert_includes last_response.body, 'Focus Mode'
  end

  def test_focus
    get '/', {}, 'rack.session' => { time_zone: 0 }

    get '/tracker', {}, 'rack.session' => {
      focus: true,
      current_cycle: new_cycle
    }

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Rest at: 08:25:00 AM'
    assert_includes last_response.body, %q(form action="/rest" method="post")
  end

  def test_rest_button
    get '/', {}, 'rack.session' => { time_zone: 0 }

    post '/rest', {}, 'rack.session' => {
      current_cycle: new_cycle,
      accumulated_rest_time: 0
    }
    assert_equal 302, last_response.status
    assert_equal false, session[:focus]
    assert_equal 1500, session[:current_cycle].focus_duration
    assert_equal 300, session[:current_cycle].rest_time_earned
    assert_equal 300, session[:rest_reserves]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Rest Mode'
  end

  def test_rest
    get '/', {}, 'rack.session' => { time_zone: 0 }

    get '/tracker', {}, 'rack.session' => {
      focus: false,
      rest_reserves: 300,
      current_cycle: new_cycle
    }

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Focus at: 08:30:00 AM'
  end

  def test_rest_with_no_reserves
    get '/', {}, 'rack.session' => { time_zone: 0 }

    get '/tracker', {}, 'rack.session' => {
      focus: false,
      current_cycle: new_cycle,
      rest_reserves: -120
    }

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Rest not recommended.'
  end

  def test_log
    get '/', {}, 'rack.session' => { time_zone: 0 }

    create_yaml_file('user_data.yml', '{}')

    post '/focus', {}, 'rack.session' => { current_cycle: new_cycle }
    get '/log'
    assert_equal 200, last_response.status
    assert_includes last_response.body, '2020-01-12'

    get '/log/2020-01-12'
    assert_equal 200, last_response.status
    assert_includes last_response.body, '2020-01-12'
    assert_includes last_response.body, 'Focus: 08:00:00 AM - 08:25:00 AM'
  end

  def test_sign_up_form
    get '/sign_up'

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<button type="submit">Sign Up)
  end

  def test_sign_up
    create_yaml_file('users.yml', '{}')
    post '/sign_up', username: 'user', password: 'password', time_zone: '-7'
    assert_equal 302, last_response.status

    get last_response['Location']
    assert_includes last_response.body, 'Account successfully created'
    assert_includes last_response.body, %q(<button type="submit">Sign In)

    post '/sign_up', username: 'user', password: 'password'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'That username is already taken.'
  end

  def test_sign_up_without_username_or_password
    post '/sign_up', username: '', password: '', time_zone: ''
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Please enter a username and password.'
  end

  def test_sign_up_without_time_zone
    create_yaml_file('users.yml', '{}')
    post '/sign_up', username: 'test', password: 'test', time_zone: ''
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Please select your current local time.'
  end

  def test_sign_in_form
    get '/sign_in'
    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<button type="submit">Sign In)
  end

  def test_sign_in
    create_yaml_file('users.yml', '{}')
    post '/sign_up', username: 'user', password: 'password', time_zone: '-7'

    post '/sign_in', username: 'user', password: 'password'
    assert_equal 302, last_response.status

    get last_response['Location']
    assert_equal 'user', session[:username]
    assert_equal -7, session[:time_zone]
    assert_includes last_response.body, 'user'
  end

  def test_invalid_sign_in
    create_yaml_file('users.yml', '{}')
    post '/sign_up', username: 'user', password: 'password', time_zone: '-7'

    post '/sign_in', username: 'bad_user', password: 'password'
    assert_equal 422, last_response.status

    refute_equal 'bad_user', session[:username]
    assert_includes last_response.body, 'bad_user'
    assert_includes last_response.body, %q(<button type="submit">Sign In)
  end
end
