def update_targets(inspector, config)

  require 'json'
  #data = JSON.parse(File.read("./config/10017.json"))
  data = JSON.parse(File.read("./config/#{config}.json"))

  #this will populate a blank target section - usually for a new region or account
  if inspector.list_assessment_targets()[0].count == 0
    data.each do |entry|
      resource = []
      entry['keys'].each do |key|
        if key["Value"] == "" || key["Value"] = " " || !hashy.has_key?("Value")
          key_value = nil
        else
          key_value = key["Value"]
        end
        resource << {key: key["Name"], value: key_value}
      end
      inspector.create_assessment_target({
          assessment_target_name: entry['Target'],
          resource_group_arn: inspector.create_resource_group({ resource_group_tags: resource }).resource_group_arn
      })
    end

  return
  end

  #otherwise we are updating an existing list of targets
  data.each do |entry|
    resource = []
    target = nil
    present = false
    entry['keys'].each {|key|  resource << {key: key["Name"], value: key["Value"]}}
    inspector.describe_assessment_targets({ assessment_target_arns: inspector.list_assessment_targets()[0]})[0].each {|n| target = n unless n.name != entry['Target']}
    if target == nil
      inspector.create_assessment_target({
      assessment_target_name: entry['Target'],
      resource_group_arn: inspector.create_resource_group({ resource_group_tags: resource }).resource_group_arn
      })
       puts "Creating target #{entry['Target']}"
    else
     puts "Updating old target #{target.name}"
     inspector.update_assessment_target({
       assessment_target_arn: target.arn,
       assessment_target_name: target.name,
       resource_group_arn: inspector.create_resource_group({ resource_group_tags: resource }).resource_group_arn
      })
    end
    entry['assessments'].each{|assessment| assessment_present(inspector, entry['Target'], assessment['Duration'], assessment['Ruleset'], assessment['Name'])} unless entry['assessments'].nil?
  end
end

def build_target(ec2, inspector, catchall)

  list = File.readlines('config/catchall').map(&:strip)
  # run through list of instances, confirm if any instance has that name
  #if the name exists, then add it to the custom JSON



end
