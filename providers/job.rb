#
# Cookbook Name:: jenkins
# Provider:: job
#
# Author:: Doug MacEachern <dougm@vmware.com>
# Author:: Fletcher Nichol <fnichol@nichol.ca>
# Author:: Seth Chisamore <schisamo@opscode.com>
#
# Copyright:: 2010, VMware, Inc.
# Copyright:: 2012, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# private

def validate_job_config!
  unless ::File.exist?(@new_resource.config)
    fail "'#{@new_resource.config}' does not exist or is not a valid Jenkins config file!"
  end
end

def exists?
  Chef::Log.debug("Checking if #{@new_resource} exists")
  # ugly paste'n'hack to check if job exists without using http checks (this is auth-friendly)
  url = node['jenkins']['server']['url']
  home = node['jenkins']['node']['home']
  username = node['jenkins']['cli']['username']
  password = node['jenkins']['cli']['password']
  password_file = node['jenkins']['cli']['password_file']
  key_file = node['jenkins']['cli']['key_file']
  jvm_options = node['jenkins']['cli']['jvm_options']

  # recipes will chown to jenkins later if this doesn't already exist
  directory 'home for jenkins-cli.jar' do
    action :create
    path node['jenkins']['node']['home']
  end

  cli_jar = ::File.join(home, 'jenkins-cli.jar')
  remote_file cli_jar do
    source "#{url}/jnlpJars/jenkins-cli.jar"
    not_if { ::File.exists?(cli_jar) }
  end

  java_home = node['jenkins']['java_home'] || (node.attribute?('java') ? node['java']['java_home'] : nil)
  if java_home.nil?
    java = 'java'
  else
    java = '"' << ::File.join(java_home, 'bin', 'java') << '"'
  end

  java << " #{jvm_options}" if jvm_options

  if key_file
    command = "#{java} -jar #{cli_jar} -i #{key_file} -s #{url} get-job #{@new_resource.job_name}"
  else
    command = "#{java} -jar #{cli_jar} -s #{url} get-job #{@new_resource.job_name}"
  end

  command << " --username #{username}" if username
  command << " --password #{password}" if password
  command << " --password_file #{password_file}" if password_file

  @exists ||= begin
    cmd = Mixlib::ShellOut.new(command, :cwd => home)
    cmd.run_command
    Chef::Log.debug(cmd.stdout)
    if cmd.exitstatus > 0
      Chef::Log.debug("#{@new_resource} does not exist")
      false
    else
      Chef::Log.debug("#{@new_resource} exists")
      true
    end
  rescue
    Chef::Log.debug("Check failed. #{@new_resource} does not exist")
    false
  end
end

# public

def load_current_resource
  @current_resource = Chef::Resource::JenkinsJob.new(@new_resource.name)
end

def action_update
  validate_job_config!
  if exists?
    Chef::Log.debug("#{@new_resource} exists - updating")
    jenkins_cli "update-job #{@new_resource.job_name} < #{@new_resource.config}"
  else
    Chef::Log.debug("#{@new_resource} does not exist - creating.")
    jenkins_cli "create-job #{@new_resource.job_name} < #{@new_resource.config}"
  end
  new_resource.updated_by_last_action(true)
end

alias_method :action_create, :action_update

def action_delete
  jenkins_cli "delete-job '#{@new_resource.job_name}'"
end

def action_disable
  jenkins_cli "disable-job '#{@new_resource.job_name}'"
end

def action_enable
  jenkins_cli "enable-job '#{@new_resource.job_name}'"
end

def action_build
  Chef::Log.debug("Building #{@new_resource.job_name}")
  jenkins_cli "build '#{@new_resource.job_name}'"
end
