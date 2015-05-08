require './config'

def iam
  @iam ||= Aws::IAM::Client.new(region: @region)
end

def create_group
  resp = iam.create_group group_name: group_name
  ap resp
end

def attach_group_policy
  policy_arn = 'arn:aws:iam::aws:policy/AdministratorAccess'
  resp = iam.attach_group_policy group_name: group_name, policy_arn: policy_arn
  ap resp
end

def create_user
  user_name = 'Adele'
  resp = iam.create_user user_name: user_name
  ap resp
end

def add_user_to_group
  group_name = 'Administrators'
  user_name = 'Adele'
  resp = iam.add_user_to_group group_name: group_name, user_name: user_name
  ap resp
end
