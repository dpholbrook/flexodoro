# # handles reading and writing user data to and from YAML files
# class Data
#
#   def log(cycle, user_id)
#     cycle_data = cycle.data
#
#     sql = <<~SQL
#       INSERT INTO cycles (user_id, focus_start, rest_start, rest_end, duration)
#       VALUES ($1, $2, $3, $4, $5, $6)
#     SQL
#     query(
#       sql,
#       user_id,
#       cycle_data[:focus_start],
#       cycle_data[:rest_start],
#       cycle_data[:rest_end],
#       cycle_data[:duration]
#     )
#   end
#   # class << self
#     def self.load_user_data(username)
#       if ENV['RACK_ENV'] == 'test'
#         YAML.load(File.read('test/data/user_data.yml'))
#       elsif File.exist?("data/#{username}_data.yml")
#         data = YAML.load(File.read("data/#{username}_data.yml"))
#       else
#         {}
#       end
#     end
#     #
#     # def write_data(data, username)
#     #   if ENV['RACK_ENV'] == 'test'
#     #     File.open('test/data/user_data.yml', 'w') do |file|
#     #       file.write(data.to_yaml)
#     #     end
#     #   else
#     #     File.open("data/#{username}_data.yml", 'w') do |file|
#     #       file.write(data.to_yaml)
#     #     end
#     #   end
#     # end
#     #
#     # def log(cycle, username)
#     #   new_data = update_data(cycle, username)
#     #   write_data(new_data, username)
#     # end
#     #
#     # def update_data(cycle, username)
#     #   data = load_user_data(username)
#     #   date = cycle.date
#     #
#     #   if data.key?(date)
#     #     data[date] << cycle.data
#     #   else
#     #     data[date] = [cycle.data]
#     #   end
#     #
#     #   data
#     # end
#
#     # def dates_and_durations(data)
#     #   totals = {}
#     #   data.each do |date, cycles|
#     #     totals[date] = cycles.sum do |cycle|
#     #       cycle[:duration]
#     #     end
#     #   end
#     #
#     #   totals
#     # end
#
#   #   def total_duration_for_date(data_for_date)
#   #     data_for_date.sum do |cycle|
#   #       cycle[:duration]
#   #     end
#   #   end
#   # end
# end
