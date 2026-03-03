require 'csv'
require 'uri'
require 'json'
require 'net/http'
require 'fileutils'
require 'time'

# ============================================================
# CONFIGURATION — edit these constants for each use case
# ============================================================

BASE_URL    = ENV.fetch('API_BASE_URL', 'https://api.example.com')
ENDPOINT    = '/your/endpoint'
HTTP_METHOD = :post  # :get, :post, :put, :patch, :delete

HEADERS = {
  'ApiKey'       => ENV['API_KEY'],
  'Content-Type' => 'application/json',
  'Accept'       => 'application/json'
}.freeze

# ============================================================
# BUILD REQUEST BODY — customize per API
# ============================================================

def build_request_body(row)
  JSON.dump({
    full_street_address: {
      address_line_1: row['address_line_1'],
      address_line_2: row['address_line_2'],
      city:           row['city'],
      state:          row['state'],
      postal_code:    row['postal_code'],
      country_code:   'US'
    }
  })
end

# ============================================================
# EVALUATE RESPONSE — customize success condition per API
# ============================================================

def success?(response)
  return false if response.nil?
  # Example: check a specific key in the response
  response['is_valid'] == true
end

def result_row(row, response, success)
  base = row.to_h
  if success
    base.merge('status' => 'success', 'message' => "Valid address: #{row['address_line_1']}, #{row['city']}, #{row['state']}")
  else
    base.merge('status' => 'failure', 'message' => "Invalid address: #{row['address_line_1']}, #{row['city']}, #{row['state']}")
  end
end

# ============================================================
# HTTP HELPER
# ============================================================

REQUEST_CLASSES = {
  get:    Net::HTTP::Get,
  post:   Net::HTTP::Post,
  put:    Net::HTTP::Put,
  patch:  Net::HTTP::Patch,
  delete: Net::HTTP::Delete
}.freeze

def build_request(method, uri, headers, body = nil)
  klass = REQUEST_CLASSES.fetch(method) { raise ArgumentError, "Unsupported HTTP method: #{method}" }
  req = klass.new(uri)
  headers.each { |k, v| req[k] = v }
  req.body = body if body && !%i[get delete].include?(method)
  req
end

# ============================================================
# ARGUMENT VALIDATION & FILE SETUP
# ============================================================

if ARGV.length != 1
  warn "Usage: ruby #{File.basename(__FILE__)} <input_file>"
  warn "  Input file should be located in the inputs/ directory"
  exit 1
end

input_file = File.join(__dir__, 'inputs', ARGV[0])

unless File.exist?(input_file)
  warn "Input file not found: #{input_file}"
  exit 1
end

output_dir  = File.join(__dir__, 'outputs')
FileUtils.mkdir_p(output_dir)
timestamp   = Time.now.strftime('%Y%m%d_%H%M%S')
output_file = File.join(output_dir, "results_#{timestamp}.csv")

# ============================================================
# MAIN LOOP
# ============================================================

uri            = URI("#{BASE_URL}#{ENDPOINT}")
success_count  = 0
failure_count  = 0
error_count    = 0

CSV.open(output_file, 'w') do |output_csv|
  headers_written = false

  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
    CSV.foreach(input_file, headers: true) do |row|
      begin
        body    = %i[get delete].include?(HTTP_METHOD) ? nil : build_request_body(row)
        request = build_request(HTTP_METHOD, uri, HEADERS, body)

        raw_response = http.request(request)
        response     = JSON.parse(raw_response.body)

        # Uncomment to drop into an interactive debugger and inspect `response`:
        # binding.irb

        if success?(response)
          success_count += 1
          row_data = result_row(row, response, true)
        else
          failure_count += 1
          row_data = result_row(row, response, false)
        end

        unless headers_written
          output_csv << row_data.keys
          headers_written = true
        end
        output_csv << row_data.values

      rescue JSON::ParserError => e
        warn "JSON parse error on row (#{row['address_line_1']}): #{e.message}"
        error_count += 1
      rescue Net::HTTPError, Errno::ECONNREFUSED, SocketError => e
        warn "Network error on row (#{row['address_line_1']}): #{e.message}"
        error_count += 1
      end
    end
  end
end

puts "\nComplete. Results written to: #{output_file}"
puts "  Successes : #{success_count}"
puts "  Failures  : #{failure_count}"
puts "  Errors    : #{error_count}"
