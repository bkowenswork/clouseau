### basic functions used by other library calls

# get an individual assessment based on it's name
def get_assessment(inspector, assessment)
  result = "NA"
  inspector.list_assessment_templates({max_results:999})[0].each {|n| inspector.describe_assessment_templates({ assessment_template_arns: [n]})[0].each { |n| result = n if n.name == assessment} }
  return result
end

# get an individual target based on it's name
def get_target(inspector, target)
  result = "NA"
  inspector.describe_assessment_targets({ assessment_target_arns: inspector.list_assessment_targets({})[0] })[0].each{|n| result = n if n.name == target}
  return result
end

# get a run based on it's arn
def get_run(inspector, run)
  return inspector.describe_assessment_runs({ assessment_run_arns: [run], })[0].first
end

# get a finding based on it's arn
def get_findings(inspector, runArn)
  return inspector.list_findings({assessment_run_arns: [runArn, ],max_results: 9999, })[0]
end

# get a list of targets in the current region
def list_targets(inspector)
  inspector.describe_assessment_targets({ assessment_target_arns: inspector.list_assessment_targets({})[0] })[0].each{|n| puts "#{n.name}"}
end

# get a list of assessments in the current region
def list_assessments(inspector)
  inspector.list_assessment_templates({max_results:999})[0].each {|n| inspector.describe_assessment_templates({ assessment_template_arns: [n]})[0].each { |template| puts template.name} }
end

# get a list of runs in the current region
def list_runs(inspector)
  report = []
  inspector.list_assessment_runs({max_results:999})[0].each {|n| inspector.describe_assessment_runs({ assessment_run_arns: [n]})[0].each { |run| report << run} }
  return report
end

# get a list of the rulesets used for an assessment run
def list_rulesets(inspector)
  inspector.describe_rules_packages({rules_package_arns: inspector.list_rules_packages({})[0] })[0]
end

# remove a target based on it's name
def remove_target(inspector, target)
  theTarget = get_target(inspector, target)
  inspector.delete_assessment_target({ assessment_target_arn: theTarget.arn }) unless theTarget == "NA"
  list_targets(inspector)
end

# remove an assssment based on it's name
def remove_assessment(inspector, assessment)
  theAssessment = get_assessment(inspector, assessment)
  inspector.delete_assessment_template({ assessment_target_arn: theAssessment.arn }) unless theAssessment == "NA"
end

# more specialized functions

# filter through the findings and determine the count of each category
def finding_results(findings)
  report = []
  report["High"] = 0
  report["Medium"] = 0
  report["Low"] = 0
  report["Informational"] = 0
  findings[0].each { |finding|  report[inspector.describe_findings({finding_arns: [finding,],}).findings[0].severity] = report[inspector.describe_findings({finding_arns: [finding,],}).findings[0].severity] + 1}
  return report
end

# confirm that a chosen target actually exists in this region
def target_exists(inspector, target)
  present = false
  inspector.describe_assessment_targets({assessment_target_arns: inspector.list_assessment_targets({})[0]})[0].each{|n| present = true unless n.name != target}
  return present
end

def assessment_present(inspector, target, duration, ruleset, name)
  present = false
  targetArn = ""
  duration_adjusted = duration.to_i * 60

  rulesetArns = {}
  rulesetArns['RUN'] = "Runtime Behavior Analysis"
  rulesetArns['VUL'] = "Common Vulnerabilities and Exposures"
  rulesetArns['CIS'] = "CIS Operating System Security Configuration Benchmarks"
  rulesetArns['BEST'] = "Security Best Practices"

  templateArn = nil
  assessment = "#{target}_#{name}_#{duration}-min_ruleset-#{ruleset.join('')}"

  inspector.describe_rules_packages({ rules_package_arns: inspector.list_rules_packages({})[0] })[0].each{|n| rulesetArns.each{|rule| rulesetArns[rule[0]] = n.arn if n.name == rule[1]} }

  rulesetArn = []
  ruleset.each do |rule|
    rulesetArn << rulesetArns[rule]
  end

  if (get_assessment(inspector, assessment) == "NA")
    puts "Creating the assessment"
    result = inspector.create_assessment_template({
                                                      assessment_target_arn: get_target(inspector, target).arn,
                                                      assessment_template_name: assessment,
                                                      duration_in_seconds: duration_adjusted,
                                                      rules_package_arns: rulesetArn,
                                                  })
    return {"name" => assessment, "arn" => result[0]}
  else
    return {"name" => assessment, "arn" => templateArn}
  end

end

def run_assessment(inspector,assessment)
  assessmentName = get_assessment(inspector, assessment)
  abort("Unable to find assessment.") if assessmentName == "NA"
  runName = "#{assessmentName.name}-#{Time.now.to_i}"

  begin
    resp = inspector.start_assessment_run({ assessment_run_name: runName, assessment_template_arn: assessmentName.arn,})
    return runName
  rescue
    abort("Unable to execute run.")
  end
end

def run_review(inspector, runName)
  runArn = ""
  list_runs(inspector).each do |run|
    runArn = run.arn if run.name.include? "#{imageid}_15-min_ruleset-BESTRUNVUL"
  end
  abort("Unable to find the run.") if runArn == ""
  puts "Waiting for run to finish, this will take 15 minutes."
  sleep 18*60
  abort ("Seems to be a problem with the run.  Please check.") unless get_run(inspector, runArn).state.include? "COMPLETED"
  findings = get_findings(inspector, runArn)
  finding_results(findings)

  report = inspector.get_assessment_report({assessment_run_arn: arn, report_file_format: 'PDF', report_type: 'FINDING'})
  s3 = Aws::S3::Resource.new(region: 'us-west-2')
  s3.bucket('test-inspector-reports').object('test.pdf').put(body: open(report.url).read)
end

