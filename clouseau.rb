#!/usr/bin/ruby
require 'aws-sdk'
require 'optparse'
require './lib/inspector'
require './lib/assessment'
require './lib/target'

options = {:run => nil, :duration => nil, :ruleset => nil}
regions = ['all', 'us-east-1','us-west-1','us-west-2','ap-south-1','ap-northeast-2','ap-southeast-2','ap-northeast-1','eu-west-1']
@aws_regions = ['us-east-1','us-west-1','us-west-2','ap-south-1','ap-northeast-2','ap-southeast-2','ap-northeast-1','eu-west-1']

parser = OptionParser.new do|opts|
  opts.banner = "Usage: inspect.rb [options]"
  opts.on('--list-targets') do
    puts "Available targets:"
    list_targets(inspector).each {|n| puts "#{n.name}"}
    exit
  end

  opts.on('--assessment assessment' ) do |assessment|
    options[:assessment] = assessment.to_s.chomp
  end

  opts.on('--ruleset ruleset') do |ruleset|
    options[:ruleset] = ruleset.to_s.chomp
  end

  opts.on('--duration duration') do |duration|
    options[:duration] = duration.to_s.chomp
  end

  opts.on('--accesskey accesskey') do |accesskey|
    options[:accesskey] = accesskey.to_s.chomp
  end

  opts.on('--secretkey secretkey') do |secretkey|
    options[:secretkey] = secretkey.to_s.chomp
  end

  opts.on('--region region') do |region|
    region.to_s.strip
    abort("This region is not available.") unless regions.include? region
    options[:region] = (region == 'all') ? 'us-east-1' : region
    options[:allregions] = (region == 'all') ? true : false
  end

  opts.on('--account account') do |account|
    abort("Please specify accounts delimited by comma, no spaces, or put local if you are testing.") if account == nil
    options[:accounts] = account.to_s.strip.split(",")
  end

  opts.on('--config config') do |config|
    options[:config] = config.to_s.strip
  end

  opts.on('--agentrefresh agentrefresh') do |agentrefresh|
    options[:agentrefresh] = agentrefresh.to_s.strip
  end

  opts.on('--removetarget removetarget') do |removetarget|
    options[:removetarget] = removetarget.to_s.strip
  end

  opts.on('--removeassessment removeassessment') do |removeassessment|
    options[:removeassessment] = removeassessment.to_s.strip
  end

  opts.on('--review review') do |review|
    options[:review] = review.to_s.strip
  end

  opts.on('--list list') do |list|
    options[:list] = list.to_s.chomp
  end

  opts.on('--run run') do |run|
    options[:run] = run.to_s.chomp
  end

  opts.on('-h', '--help', 'help') do
    puts "Instructions"
    exit
  end

end

parser.parse!

@options = options
def looper(callback, *args)
  loopregions = (@options[:allregions] == true )? @aws_regions : @options[:region].split(",")

  @options[:accounts].each do |account|
    loopregions.each do |loopregion|
#      begin
      puts "Region is #{loopregion}, account is #{account}"
      sts_credentials = Aws::AssumeRoleCredentials.new(role_arn: "arn:aws:iam::#{account}:role/inspector-assume-role",  role_session_name: account, region: loopregion)
      inspector = Aws::Inspector::Client.new(region: loopregion, credentials: sts_credentials)
      iam = Aws::IAM::Client.new(region: loopregion, credentials: sts_credentials)
      abort("Unable to find or create the inspector role attached to account #{account} for #{loopregion}.  Please check your access rights.") unless role_precheck(iam,inspector) == true
      callback.call(inspector, *args)
#     rescue
#      abort("This account #{account} does not have appropriate role sharing via assumed role.  Ask Elnicki about it")
#    end

    end

  end
end

if (options[:list] != nil) && (options[:agentrefresh] == nil) && (options[:run] == nil) &&  (options[:removetarget] == nil) &&  (options[:removeassessment] == nil)
  looper(method(:list_assessments)) if options[:list] == "assessments"
  looper(method(:list_targets)) if options[:list] == "targets"
  looper(method(:list_runs)) if options[:list] == "runs"
  exit
else
  abort("Please do not use other function calls while rquesting a list.")
end

if (options[:agentrefresh] != nil) && (options[:run] == nil) && (options[:removetarget] == nil) && (options[:removeassessment] == nil) && (options[:review] == nil)
  looper(method(:update_targets), options[:agentrefresh])
  #update_targets(inspector, options[:agentrefresh])
  exit
else
  abort("agentrefresh should be run solo, do not include run, review or removal functions.")
end

if (options[:run] != nil) && (options[:agentrefresh] == nil) && (options[:removetarget] == nil) && (options[:removeassessment] == nil) && (options[:review] == nil)
  looper(method(:run_assessment), options[:run])
  exit
else
  abort("run should be run solo, do not include agentrefresh, review or removal functions.")
end

if (options[:review] != nil) && (options[:run] == nil) && (options[:agentrefresh] == nil) && (options[:removetarget] == nil) && (options[:removeassessment] == nil)
  looper(method(:run_assessment), options[:run])
  exit
else
  abort("review should be run solo, do not include run, agentrefresh or removal functions.")
end

if (options[:removetarget] != nil) && (options[:run] == nil) && (options[:agentrefresh] == nil) && (options[:review] == nil) && (options[:removeassessment] == nil)
  puts "Removing target: #{options[:removetarget]}"
  looper(method(:remove_target), options[:removetarget])
  exit
else
  abort("removetarget should be run solo, do not include run, review or other removal functions.")
end

if (options[:removeassessment] != nil) && (options[:run] == nil) && (options[:agentrefresh] == nil) && (options[:review] == nil) && (options[:removetarget] == nil)
  looper(method(:remove_assessment), options[:removeassessment])
  exit
else
  abort("removeassessment should be run solo, do not include run, review or other removal functions.")
end

if options[:ruleset] == nil
  puts "Please choose a ruleset, 1-5 are valid:"
  list_rulesets(inspector).each_with_index{|n, index| puts "#{index+1} - #{n.name}"}
  puts "5 - All Rulesets."
  exit
end

unless (options[:ruleset].to_i.to_s != options[:ruleset]) || (options[:ruleset].to_i.between?(1,5))
  puts "Please designate the ruleset choice numbers 1-5."
  list_rulesets(inspector).each_with_index{|n, index| puts "#{index+1} #{n.name}"}
  puts "5 All Rulesets."
  exit
end

unless (options[:duration] == nil) || (options[:duration].to_i.to_s != options[:duration]) || (options[:duration].to_i.between?(1,720))
  puts "Please supply a duration in numerical form between 1 and 720."
  puts "You have put #{options[:duration].to_i} it is a #{options[:duration].length} long"
  exit
end

if (options[:assessment] != nil)
  run_assessment(inspector, assessment_present(inspector, options[:run], options[:duration], options[:ruleset]))
  exit
end
