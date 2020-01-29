# handles sign up and sign in
class User
  class << self
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
      credentials = load_user_credentials

      password = BCrypt::Password.create(password).to_s
      credentials[username.strip] = { password: password, time_zone: time_zone }
      add_new_user(credentials)
    end

    def valid_credentials?(given_username, given_password)
      credentials = load_user_credentials

      if credentials.key?(given_username)
        stored_password_hash = credentials[given_username][:password]
        BCrypt::Password.new(stored_password_hash) == given_password
      else
        false
      end
    end

    def time_zone(username)
      load_user_credentials[username][:time_zone]
    end

    private

    def add_new_user(credentials)
      if ENV['RACK_ENV'] == 'test'
        File.open('test/data/users.yml', 'w') do |file|
          file.write(credentials.to_yaml)
        end
      else
        File.open('users.yml', 'w') { |file| file.write(credentials.to_yaml) }
      end
    end

    def load_user_credentials
      credentials_path =
        if ENV['RACK_ENV'] == 'test'
          File.expand_path('../test/data/users.yml', __FILE__)
        else
          File.expand_path('../users.yml', __FILE__)
        end

      YAML.load_file(credentials_path)
    end

    def invalid?(username, password)
      username.empty? || password.empty? || username == 'guest'
    end

    def username_taken?(username)
      credentials = load_user_credentials
      credentials.include?(username)
    end

    def time_not_selected?(time_zone)
      time_zone.empty?
    end
  end
end
