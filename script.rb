require 'pry'
require 'csv'
require 'uri'
require 'json'
require 'net/http'

if ARGV.length != 1
  puts 'please pass a single input file as an argument to the script'
  puts 'exiting script...'
  exit
end

file = File.expand_path(File.dirname(__FILE__)) + "/inputs/#{ARGV[0]}"
url = URI("")
https = Net::HTTP.new(url.host, url.port)
https.use_ssl = true
#feel free to utilize any HTTP library (faraday, HTTParty etc)

request = Net::HTTP::Get.new(url)

request["ApiKey"] = ENV['API_KEY']
request["Content-Type"] = 'application/json'

@success_results = []
@failure_results = []

#build the request body, hyptothetical example below
#mix and match attributes that are pulled from CSV or hard coded
CSV.foreach(file, headers: true) do |row|
  request.body = JSON.dump({
      "full_street_address": {
        "address_line_1": row['address_line_1'],
        "address_line_2": row['address_line_2'],
        "city": row['city'],
        "state": row['state'],
        "postal_code": row['postal_code'],
        "country_code": "US"
      }
    })

unformatted_response = https.request(request)
response = JSON.parse(unformatted_response.body)

#you should have a JSON object now. Set a breakpoint (binding.pry) to figure out the best way to parse it
binding.pry
#set conditions below for whatever you're looking for in the response (ie a 'true' value)
  unless response.nil?
    if response[0] = true
      @success_message = "yes, business is located at #{row["address_line_1"]} in #{row["city"]}, #{row["state"]}"
      @results_file << @success_message
    else
      @failure_message = "no, #{row["address_line_1"]} in #{row["city"]}, #{row["state"]} is not a valid business address"
      @results_file << @failure_message
    end
  end
end
