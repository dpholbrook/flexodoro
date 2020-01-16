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

    get last_response["Location"]
    assert_includes last_response.body, "Focus Mode"
  end

  def test_second_focus_button_click
    post "/focus", {}, { "rack.session" => {
                                             rest_start_time: Time.new(2020, 1, 12, 7, 55, 0),
                                             accumulated_rest_time: 300
                                            } }
    assert_equal 302, last_response.status
    assert_equal Time.new(2020, 1, 12, 8, 0, 0), session[:rest_end_time]
    assert_equal 300, session[:elapsed_time_rested]
    assert_equal 0, session[:accumulated_rest_time]

    get last_response["Location"]
    assert_includes last_response.body, "Focus Mode"
  end

  def test_write_to_yaml_file
    # create_yaml_file "user_data.yml"
    # assert_equal [{:focus_start_time=>2020-01-12 07:30:00 -0700, :rest_start_time=>2020-01-12 07:55:00 -0700, :rest_end_time=>2020-01-12 08:00:00 -0700}], yaml_file_content
  end

  def test_focus
    get "/focus", {}, { "rack.session" => { focus_start_time: Time.new(2020, 1, 12, 8, 0, 0) } }

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
    assert_equal 1500, session[:elapsed_time_focused]
    assert_equal 300, session[:new_rest_time_earned]
    assert_equal 300, session[:accumulated_rest_time]

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Rest Mode"
  end

  def test_rest
    get "/rest", {}, { "rack.session" => {
                                          rest_start_time: Time.new(2020, 1, 12, 8, 25, 0),
                                          accumulated_rest_time: 300
                                         }}

    assert_equal last_response.status, 200
    assert_includes last_response.body, "Focus at:"
    assert_equal Time.new(2020, 1, 12, 8, 30, 0), session[:next_suggested_focus_mode]
  end

  def test_rest_with_no_reserves
    get "/rest", {}, { "rack.session" => {
                                          rest_start_time: Time.new(2020, 1, 12, 8, 25, 0),
                                          accumulated_rest_time: -120
                                         }}

    assert_equal last_response.status, 200
    assert_includes last_response.body, "Rest not recommended."
  end


end
