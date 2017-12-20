def role_precheck(iam,inspector)
  inspectorArn = "createMe"
  iam.list_roles[0].each{|n| inspectorArn = n.arn unless n.role_name != 'inspector'}
  if inspectorArn != "createMe"
  #   resp = iam.create_role({
  #        assume_role_policy_document: '{"Version": "2012-10-17","Statement": [{"Sid": "","Effect": "Allow","Principal": {"Service": "inspector.amazonaws.com"},"Action": "sts:AssumeRole","Condition": {"StringEquals":{"sts:ExternalId": "922163500101"}}}]}',
  #        path: "/",
  #        role_name: "inspector",
  #    })
  #   inspectorArn = resp[0].arn
  #
  #   resp = iam.put_role_policy({
  #        policy_document: '{"Version": "2012-10-17","Statement": [{"Effect": "Allow","Action": ["ec2:DescribeInstances"],"Resource": ["*"]}]}',
  #        policy_name: "inspectorEC2describe",
  #        role_name: "inspector",
  #    })
    if iam.get_role({role_name: "inspector"})[0].assume_role_policy_document.to_s.include?"inspector"
      begin
        resp = inspector.register_cross_account_access_role({ role_arn: inspectorArn,})
        puts "Registering inspector."
        return true
      rescue
        puts "Inspector could not register the service in this region.  It is possible it is not yet supported."
        return false
      end
    end
  else
#    inspector.register_cross_account_access_role({ role_arn: inspectorArn,})
    puts "The inspector role does not exist, please create this role."
  end

end
