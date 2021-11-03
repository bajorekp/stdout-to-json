require 'json'
require 'date'
require 'open3'

class StdoutToJson
  def self.log(line)
    puts convert(line)
    STDOUT.flush
  end

  def self.convert(line)
    clean_line = line.strip

    basic_log = {
      '@version' => 1,
      '@timestamp' => format_dt(DateTime.now),
      'message' => clean_line
    }

    complete_log = basic_log.merge(request_log(clean_line))

    JSON.dump(complete_log)
  end

  def self.request_log(line)
    match_result = match_request_line(line)

    return {} unless match_result

    log = {}
    log['@timestamp'] = format_dt DateTime.strptime(match_result['datetime'], '%d/%b/%Y:%H:%M:%S %Z')
    log['message'] = request_message(match_result)
    log['method'] = match_result['method']
    log['path'] = match_result['path']
    log['status'] = match_result['status']
    log['clientip'] = match_result['clientip']
    log['referrer'] = match_result['referrer']
    log['user_agent'] = "#{match_result['user_agent']} #{match_result['http_version']}"
    log
  rescue => e
    {'message' => format_error(line, e)}
  end

  def self.format_dt(dt)
    dt.rfc3339(3)
  end

  def self.format_error(line, e)
    "Error formatting line `#{line}`: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
  end

  def self.match_request_line(line)
    request_log = /(?<clientip>[\d\.]+)\s\-\s\w*\-\s\[(?<datetime>[\w\d\.\/\: \+]+)\]\s\"(?<method>\w+)\s(?<path>.+?)\s(?<http_version>HTTP\/[\w\.]+)\"\s(?<status>\d+)\s\-\s\"(?<referrer>.*?)\"\s"(?<user_agent>.*?)\"(?<message_rest>.*)/

    request_log.match(line)
  end

  def self.request_message(match_result)
    method = match_result['method']
    path = match_result['path']
    status = match_result['status']
    "#{status} - #{method} #{path} #{match_result['message_rest']}"
  end
end

def trap_errors
  trap "SIGINT" do
    raise Interrupt, "SIGINT"
  end
   
  trap "SIGTERM" do
    raise Interrupt, "SIGTERM"
  end
end

def pipe_logs(io)
  io.each_line { |line| StdoutToJson.log(line) }
end

# RunS command and converts its STDOUT and STDERR into JSON format.
#
# Example
#
#     ruby stdout_to_json.rb 'ping 1.1.1.1'
#
def run_command
  return if defined?(RSpec)
  
  command = ARGV.join(" ")
  
  trap_errors

  StdoutToJson.log "Ruby version: #{`ruby -v`}"
  StdoutToJson.log "Starting command: #{command}"

  stdin, stdout_and_stderr, wait_thr = Open3.popen2e(command)
  StdoutToJson.log "Command started with status: #{wait_thr.status}"

  begin
    pipe_logs(stdout_and_stderr)
    exit_code = wait_thr.value.exitstatus
    StdoutToJson.log("Exiting with status #{exit_code}")
    exit exit_code
  rescue Interrupt => e
    wait_thr.terminate
    stdin.close
    stdout_and_stderr.close
    StdoutToJson.log("Exiting because of Interrupt #{e}")
    exit 0
  end
end


# Converts logs from STDIN to JSON
#
# Example
#     
#     ping 1.1.1.1 | ruby stdout_to_json.rb
#
# To get the exit code set pipefail option:
#
#     set -o pipefail
#     ping 1.1.1.1 | ruby stdout_to_json.rb
#     echo $pipestatus # => 1 0
#     echo $? # => 1
#
# Or with one line:
#
#     bash -o pipefail -c '(ping 1.1.1.1 && exit 128) | ruby stdout_to_json.rb'
#     echo $? # => 1
#
# To convert also error logs redirect stderr to stdout.
#
#     ping 1.1.1.1 2>&1 | ruby stdout_to_json.rb
#
def read_from_stream
  return if defined?(RSpec)

  `set -o pipefail`

  begin
    pipe_logs(ARGF)
  rescue Interrupt => e
    exit 0
  end
end

# read_from_stream
run_command