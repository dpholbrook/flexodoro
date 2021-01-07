# handles sign up and sign in
class User
  def initialize
    @storage = DatabasePersistence.new
    @user_credentials = @storage.load_user_credentials
  end

  # sign up

  def invalid_sign_up_message(username, password, time_zone)
    if invalid?(username, password)
      'Please enter a valid username and password.'
    elsif username_taken?(username)
      'That username is already taken.'
    elsif time_not_selected?(time_zone)
      'Please select your current local time.'
    end
  end

  def create_account(username, password, time_zone)
    password = BCrypt::Password.create(password).to_s
    @storage.create_account(username.strip, password, time_zone)
  end

  def invalid?(username, password)
    username.empty? || password.empty? || username == 'guest'
  end

  def username_taken?(username)
    @user_credentials.any? do |user|
      user[:username] == username
    end
  end

  def time_not_selected?(time_zone)
    time_zone.empty?
  end

  # sign in

  def valid_user(given_username, given_password)
    @user_credentials.select do |user|
      user[:username] == given_username &&
      BCrypt::Password.new(user[:password]) == given_password
    end.first
  end
end
