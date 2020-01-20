ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "pry"
require "fileutils"

require_relative "../flexodoro"

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

  def create_yaml_file(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def yaml_file_content
    YAML.load(File.read("test/data/user_data.yml"))
  end

  def session
    last_request.env["rack.session"]
  end

  def test_home
    get "/"

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(form action="/focus")
  end

  def test_first_focus_button_click
    post "/focus"
    assert_equal 302, last_response.status
    assert_equal Time.new(2020, 1, 12, 8, 0, 0), session[:focus_start_time]
    assert_equal true, session[:focus]

    get last_response["Location"]
    assert_includes last_response.body, "Focus Mode"
  end

  def test_second_focus_button_click
    create_yaml_file "user_data.yml", "[]"
    post "/focus", {}, { "rack.session" => {
                                             rest_start_time: Time.new(2020, 1, 12, 7, 55, 0),
                                             accumulated_rest_time: 300
                                            } }
    assert_equal 302, last_response.status
    assert_equal Time.new(2020, 1, 12, 8, 0, 0), session[:rest_end_time]
    assert_equal 300, session[:elapsed_time_rested]
    assert_equal 0, session[:accumulated_rest_time]
    assert_equal true, session[:focus]

    get last_response["Location"]
    assert_includes last_response.body, "Focus Mode"
  end

  def test_focus
    get "/", {}, { "rack.session" => {
                                      focus: true,
                                      focus_start_time: Time.new(2020, 1, 12, 8, 0, 0)
                                      } }

    assert_equal 200, last_response.status
    suggested_rest_time = session[:focus_start_time] + SECONDS_PER_POMODORO
    assert_includes last_response.body, "#{format_time_object(suggested_rest_time)}"
    assert_includes last_response.body, %q(form action="/rest" method="post")
  end

  def test_rest_button
    post "/rest", {}, { "rack.session" => {
                                                            focus_start_time: Time.new(2020, 1, 12, 8, 0, 0),
                                                            accumulated_rest_time: 0
                                                            } }
    assert_equal 302, last_response.status
    assert_equal false, session[:focus]
    assert_equal 1500, session[:elapsed_time_focused]
    assert_equal 300, session[:new_rest_time_earned]
    assert_equal 300, session[:accumulated_rest_time]

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Rest Mode"
  end

  def test_rest
    get "/", {}, { "rack.session" => {
                                      focus: false,
                                      rest_start_time: Time.new(2020, 1, 12, 8, 25, 0),
                                      accumulated_rest_time: 300
                                     }}

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Focus at:"
    assert_equal Time.new(2020, 1, 12, 8, 30, 0), session[:next_suggested_focus_mode]
  end

  def test_rest_with_no_reserves
    get "/", {}, { "rack.session" => {
                                        focus: false,
                                        rest_start_time: Time.new(2020, 1, 12, 8, 25, 0),
                                        accumulated_rest_time: -120
                                       }}

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Rest not recommended."
  end

  def test_log
    create_yaml_file("user_data.yml", "[]")

    post "/focus", {}, { "rack.session" => {
                                            focus_start_time: Time.new(2020, 1, 12, 7, 30, 0),
                                            rest_start_time: Time.new(2020, 1, 12, 7, 55, 0)
                                            }}
    get "/log"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "12-01-2020"

    get "/log/12-01-2020"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "12/01/2020"
    assert_includes last_response.body, "Focus: 07:30:00 AM - 07:55:00 AM"
  end

  def test_sign_up_form
    get "/sign_up"

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<button type="submit">Sign Up)
  end

  def test_sign_up
    create_yaml_file("users.yml", "{}")
    post "/sign_up", { username: "user", password: "password" }
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "Account successfully created"
    assert_includes last_response.body, %q(<button type="submit">Sign In)

    post "/sign_up", { username: "user", password: "password" }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "That username is already taken."
  end

  def test_sign_in_form
    get "/sign_in"
    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<button type="submit">Sign In)
  end

  def test_sign_in
    post "/sign_in", { username: "user", password: "password" }
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal "user", session[:username]
    assert_includes last_response.body, "user"
  end

  def test_invalid_sign_in
    post "/sign_in", { username: "bad_user", password: "password" }
    assert_equal 422, last_response.status

    refute_equal "bad_user", session[:username]
    assert_includes last_response.body, "bad_user"
    assert_includes last_response.body, %q(<button type="submit">Sign In)
  end


end
