require 'rspec'
require_relative './stdout_to_json'

describe StdoutToJson do
  describe '.convert' do
    subject { described_class.convert(line) }
    let(:parsed_result) { JSON.parse(subject) }

    shared_examples "a logstash log" do
      it 'is a json' do
        expect(subject).to be_a(String)
        expect(parsed_result).to be_a(Hash)
      end

      it 'has required fields' do
        expect(parsed_result).to have_key('@version')
        expect(parsed_result['@version']).to eq(1)
        expect(parsed_result).to have_key('@timestamp')
        expect(parsed_result['@timestamp']).to be_a(String)
      end

      it 'has valid timestamp format' do
        timestamp = parsed_result['@timestamp']
        expect(timestamp).to be_a(String)
        expect(DateTime.rfc3339(timestamp)).to be_a(DateTime)
        correct_timestamp_format = /\d{4}\-\d{2}\-\d{2}T\d{2}\:\d{2}\:\d{2}\.\d{3}\+\d{2}\:\d{2}/
        expect(correct_timestamp_format).to match(timestamp)
      end
    end

    context 'with simple line' do
      let(:line) { 'Listening on port 3000' }

      it_behaves_like "a logstash log"

      it 'has a message' do
        expect(parsed_result).to have_key('message')
        expect(parsed_result['message']).to eq(line)
      end
    end

    context 'with / request log' do
      let(:line) { '128.0.0.1 - - [29/Oct/2021:12:39:45 +0000] "GET / HTTP/1.1" 200 - "" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/95.0.4638.54 Safari/537.36"' }

      # it_behaves_like "a logstash log"

      it 'has a request fields' do
        expect(parsed_result).to have_key('method')
        expect(parsed_result).to have_key('path')
        expect(parsed_result).to have_key('status')
        expect(parsed_result).to have_key('clientip')
        expect(parsed_result).to have_key('referrer')
        expect(parsed_result).to have_key('user_agent')
      end

      it 'has a valid fields' do
        expect(parsed_result['@timestamp']).to eq('2021-10-29T12:39:45.000+00:00')
        expect(parsed_result['message']).to eq('200 - GET / ')
        expect(parsed_result['method']).to eq('GET')
        expect(parsed_result['path']).to eq('/')
        expect(parsed_result['status']).to eq('200')
        expect(parsed_result['clientip']).to eq('128.0.0.1')
        expect(parsed_result['referrer']).to eq('')
        expect(parsed_result['user_agent']).to eq('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/95.0.4638.54 Safari/537.36 HTTP/1.1')
      end
    end

    context 'with / request log' do
      let(:line) { '128.0.0.1 - - [29/Oct/2021:12:39:45 +0000] "GET /favicon.ico HTTP/1.1" 404 - "http://localhost:7036/" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/95.0.4638.54 Safari/537.36"' }

      it_behaves_like "a logstash log"
    end

    context 'with / request log' do
      let(:line) { '127.0.0.1 - - [29/Oct/2021:13:35:18 +0000] "GET /one HTTP/1.1" 200 - "" "Ruby"' }

      it_behaves_like "a logstash log"
    end

    context 'with / request log' do
      let(:line) { '127.0.0.1 - - [26/Jul/2021:01:56:48 -0500] "GET /unexistent HTTP/1.1" 404 - "" "curl/7.64.0"' }

      it_behaves_like "a logstash log"
    end

    context 'with wrong datetime format in request log' do
      let(:line) { '127.0.0.1 - - [2021.10.10:13:35:18 +0000] "GET /one HTTP/1.1" 200 - "" "Ruby"' }

      it_behaves_like "a logstash log"

      it 'prints an error message' do
        message_begging = 'Error formatting line `127.0.0.1 - - [2021.10.10:13:35:18 +0000] "GET /one HTTP/1.1" 200 - "" "Ruby"`'
        expect(parsed_result['message']).to start_with(message_begging)
      end
    end

    context 'with invalid request log' do
      let(:line) { '127.0.0.1 - - [26/Jul/2021:01:56:48 -0500] other log message' }

      it_behaves_like "a logstash log"

      it 'message is a line' do
        expect(parsed_result['message']).to eq(line)
      end
    end
  end
end

describe "Integration Tests" do
  subject(:output) { `ruby stdout_to_json.rb '#{command}'` }

  let(:lines) { output.split("\n") }
  let(:json_lines) { lines.map { |line| JSON.parse(line) rescue nil }.flatten }

  context 'with simple command' do
    let(:command) { 'echo "First line"' }

    it 'converts logs from stdout to JSON' do
      expect(output).not_to be_empty
      # 3 lines for startup logs + 1 lines for script and 1 line for exit code
      expect(lines.count).to eq(5)
      expect(json_lines.length).to eq(lines.count)
    end
  end

  context "with time interval between logs" do
    let(:command) { 'echo "First line" && sleep 2 && echo "Second line"' }

    it 'has the correct JSON fields' do
      first_script_line = json_lines[3]
      second_script_line = json_lines[4]

      expect(first_script_line).to have_key('message')
      expect(first_script_line['message']).to eq('First line')
      expect(second_script_line['message']).to eq('Second line')

      first_line_timestamp = DateTime.parse(first_script_line['@timestamp']).to_time.to_i
      second_line_timestamp = DateTime.parse(second_script_line['@timestamp']).to_time.to_i
      seconds_between_logs = second_line_timestamp - first_line_timestamp

      expect(seconds_between_logs).to be_between(1, 3)
    end
  end

  context "with 0 exit code" do
    let(:command) { 'echo "a log"' }

    it 'returns 0' do
      expect(json_lines.last['message']).to eq('Exiting with status 0')
      expect($?.exitstatus).to eq(0)
    end
  end

  context "with 0 exit code" do
    let(:command) { 'exit 127' }

    it 'returns 0' do
      subject
      expect(json_lines.last['message']).to eq('Exiting with status 127')
      expect($?.exitstatus).to eq(127)
    end
  end
end