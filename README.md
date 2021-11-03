# STDOUT to JSON

Converts logs into JSON format.

The repository contains the group of methods to converts plain logs from STDOUT into JSON format.

## Quickstart

- `stdout_to_json.rb` - is the only one file with all the goodies
- `*_spec.rb` - unit and e2e tests

To start:

```bash
ruby stdout_to_json.rb YOUR_COMMAND
```

in example:

```bash
$ ruby stdout_to_json.rb 'ping -c2 1.1.1.1'

{"@version":1,"@timestamp":"2021-11-03T10:07:13.307+01:00","message":"Ruby version: ruby 2.7.0p0 (2019-12-25 revision 647ee6f091) [x86_64-darwin20]"}
{"@version":1,"@timestamp":"2021-11-03T10:07:13.307+01:00","message":"Starting command: ping -c2 1.1.1.1"}
{"@version":1,"@timestamp":"2021-11-03T10:07:13.309+01:00","message":"Command started with status: sleep"}
{"@version":1,"@timestamp":"2021-11-03T10:07:13.341+01:00","message":"PING 1.1.1.1 (1.1.1.1): 56 data bytes"}
{"@version":1,"@timestamp":"2021-11-03T10:07:13.341+01:00","message":"64 bytes from 1.1.1.1: icmp_seq=0 ttl=55 time=29.772 ms"}
{"@version":1,"@timestamp":"2021-11-03T10:07:14.352+01:00","message":"64 bytes from 1.1.1.1: icmp_seq=1 ttl=55 time=36.164 ms"}
{"@version":1,"@timestamp":"2021-11-03T10:07:14.352+01:00","message":""}
{"@version":1,"@timestamp":"2021-11-03T10:07:14.352+01:00","message":"--- 1.1.1.1 ping statistics ---"}
{"@version":1,"@timestamp":"2021-11-03T10:07:14.352+01:00","message":"2 packets transmitted, 2 packets received, 0.0% packet loss"}
{"@version":1,"@timestamp":"2021-11-03T10:07:14.352+01:00","message":"round-trip min/avg/max/stddev = 29.772/32.968/36.164/3.196 ms"}
{"@version":1,"@timestamp":"2021-11-03T10:07:14.352+01:00","message":"Exiting with status 0"}
```

or if you need a piped version change the invocation from

```ruby
# read_from_stream
run_command
```

into:

```ruby
read_from_stream
# run_command
```

and run it as such:

```bash
ping 1.1.1.1 | ruby stdout_to_json.rb
```

## Oneliners

If you don't want to use external tool, you can use a one liner as such.

```bash
ping 1.1.1.1 | ruby -r json -e 'ARGF.each_line { |line| puts JSON.dump({message: line, "time" => Time.now}) }'
```

To meet logstash requirements:

```bash
ping 1.1.1.1 | ruby -r json -r date -e 'ARGF.each_line { |line| puts JSON.dump({message: line, "@timestamp" => Time.now.to_datetime.rfc3339(3), "@version" => 1}) }'
```

exit code from the command:

```bash
bash -o pipefail -c 'ping 1.1.1.1 | ruby -r json -r date -e '"'"'trap("INT", proc { exit 0 }); ARGF.each_line { |line| puts JSON.dump({message: line, "@timestamp" => Time.now.to_datetime.rfc3339(3), "@version" => 1}) }'"'"''

echo $? # prints exit code
```

## References

- How to Get exit status of process that's piped to another? https://unix.stackexchange.com/questions/14270/get-exit-status-of-process-thats-piped-to-another
- Process Pipe output actively https://stackoverflow.com/questions/47422406/ruby-process-pipe-output-actively
- What exec command does? https://askubuntu.com/questions/525767/what-does-an-exec-command-do
