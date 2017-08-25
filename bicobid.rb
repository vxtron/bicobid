#!/usr/bin/env ruby
# encoding: utf-8

require 'httpclient'
require 'json'
require 'optparse'
require 'digest/md5'

TIME_URL = 'https://www.binance.com/exchange/public/serverTime'
PURCHASE_URL = 'https://www.binance.com/project/purchase.html'
INTERVAL = 0.2

if defined?(Encoding)
  Encoding.default_internal = Encoding::UTF_8
  Encoding.default_external = Encoding::UTF_8
end

def keepalive(handler)
  loop do
    sleep 20
    begin
      handler.get TIME_URL
    rescue
    end
  end
end

def output(text)
  text = "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] #{text}"
  puts text
  begin
    File.open("bicobid.log", "a") { |h| h.puts text }
  rescue
  end
end

def main
  config = {
    :project_id => nil,
    :price => nil,
    :amount => nil,
    :calc => false,
    :jsessionid => nil,
    :csrftoken => nil,
    :start => nil,
    :duration => 300,
    :dryrun => false,
  }

  op = OptionParser.new
  op.summary_indent = " "
  op.summary_width = 22

  op.banner = "Syntax: #{File.basename($0)} [OPTIONS]..."
  op.separator ''
  op.separator 'Valid options:'
  op.separator ''

  op.on('-i', '--id PROJECT-ID',
        'ICO Project ID (see projectId=x in URL)',
  ) do |arg|
    raise "Not a valid ID: #{arg}" unless arg.to_i > 0
    config[:project_id] = arg.to_i
  end
  op.on('-p', '--price PRICE',
        'Price of one token in the respective currency',
  ) do |arg|
    raise "Not a valid price: #{arg}" unless arg.to_f > 0
    config[:price] = arg.to_f
  end
  op.on('-a', '--amount NUM',
        "Number of tokens to buy. If suffix 'x' is used, calculate",
        'the max. number of tokens for the given currency amount.'
  ) do |arg|
    raise "Not a valid amount: #{arg}" unless arg.to_f > 0
    config[:amount] = arg.to_f
    config[:calc] = arg =~ /x$/i
  end
  op.separator ''
  op.on('-S', '-s', '--session ID',
        'JSESSIONID cookie value',
  ) do |arg|
    config[:jsessionid] = arg
  end
  op.on('-C', '-c', '--csrf TOKEN',
        'CSRFToken cookie value',
  ) do |arg|
    config[:csrftoken] = arg
  end
  op.separator ''
  op.on('--start TIME',
        'Start the bidding at the given DATE/TIME.',
        'Make sure to specify the date if the specified time',
        'is lower than the current time. Do a test-run if unsure.',
  ) do |arg|
    begin
     config[:start] = Time.parse(arg)
    rescue => exc
      raise "Not a valid timespec: #{exc}"
    end
  end
  op.on('-d', '--duration SECS',
        'Stop bidding after SECS seconds.',
        'Default: 300',
  ) do |arg|
    config[:duration] = arg.to_i
  end
  op.separator ''
  op.on('-t', '--dry-run',
        'Do a test run only'
  ) do
    config[:dryrun] = true
  end
  op.separator ''
  op.on('-h', '--help',
        'Display this help text'
  ) do
    puts op
    exit 0
  end
  op.separator ''

  begin
    op.parse!
    raise 'Please specify the project id (-i)!' unless config[:project_id]
    raise 'Please specify the token price (-p)!' unless config[:price]
    raise 'Please specify the amount of tokens to buy (-a)!' unless config[:amount]
    raise 'Please specify the JSESSIONID cookie value (-S)!' unless config[:jsessionid].to_s.strip != ''
    raise 'Please specify the CSRFToken cookie value (-C)!' unless config[:csrftoken].to_s.strip != ''
  rescue => exc
    $stderr.puts exc.to_s.capitalize
    exit 1
  end

  if op.default_argv.any?
    $stderr.puts "Extraneous arguments: #{argv.join(', ')}"
    exit 1
  end

  project_id = config[:project_id]
  price = config[:price]
  amount = config[:amount]
  amount = amount/price if config[:calc]

  amount = amount.to_i   # Binance does not support decimals in amount
  price = sprintf("%.8f", price).to_f

  output sprintf("Project #%d:\n", project_id)
  output sprintf("Number of tokens to buy: %d\n", amount)
  output sprintf("Price per token: %.8f\n", price)
  output sprintf("Total price: %.8f\n", price*amount)

  headers = {
    'Host' => 'www.binance.com',
    'User-Agent' => 'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:54.0) Gecko/20100101 Firefox/54.0',
    'Accept' => '*/*',
    'Accept-Language' => 'en-US,en;q=0.5',
    'Accept-Encoding' => 'gzip, deflate',
    'Referer' => "https://www.binance.com/icoDetails.html?projectId=#{project_id}",
    'lang' => 'en',
    'clientType' => 'web',
    'Connection' => 'keep-alive',
    'Cache-Control' => 'max-age=0',
    'CSRFToken' => Digest::MD5.hexdigest(config[:csrftoken]),
    'Cookie' => "JSESSIONID=#{config[:jsessionid]}; logined=y"
  }

  web = HTTPClient.new

  Thread.new { keepalive(web) }

  if config[:start] and config[:start] > Time.now
    output "Waiting until #{config[:start].to_s}"
    sleep 0.01 while Time.now < config[:start]
  end

  url = PURCHASE_URL
  info = { 'projectId' => project_id, 'price' => sprintf('%.8f', price), 'num' => amount }

  stop = (config[:duration]) ? Time.now + config[:duration] : 0
  while stop == 0 or Time.now < stop
    start = Time.now
    begin
      output "Bidding..."
      res = web.post(url, info, headers)
      output "#{res.body} -  #{[res.body].pack('m')}"
      if not res.status_code.between?(200,299)
        output "Bid failed with #{res.status}"
      else
        result = JSON.parse(res.body)
        if result.is_a?(Hash) and result['success']
          output "Bid accepted!"
          exit
        end
      end
    rescue => exc
      $stderr.puts "Error: #{exc}"
    end
    sleep 0.01 while (Time.now - start) < INTERVAL
  end
end

main
