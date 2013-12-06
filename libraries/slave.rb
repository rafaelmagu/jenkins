#
# Cookbook Name:: jenkins
# HWRP:: node
#
# Author:: Seth Vargo <sethvargo@gmail.com>
#
# Copyright 2013, Opscode, Inc.
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

#
#
#
class Chef
  class Resource::JenkinsSlave < Resource
    identity_attr :name

    attr_writer :exists

    def initialize(name, run_context = nil)
      super

      # Set the resource name and provider
      @resource_name = :jenkins_slave
      @provider = Provider::JenkinsSlave

      # Set default actions and allowed actions
      @action = :create
      @allowed_actions.push(:create, :delete, :connect, :disconnect, :offline, :online)

      # Set the name attribute and default attributes
      @name = name

      # State attributes that are set by the provider
      @exists = false
    end

    def name(arg = nil)
      set_or_return(:name, arg, kind_of: String)
    end

    def description(arg = nil)
      set_or_return(:description, arg, kind_of: String)
    end

    def remote_fs(arg = nil)
      set_or_return(:remote_fs, arg, kind_of: String)
    end

    def mode(arg = nil)
      set_or_return(:mode, arg, equal_to: [:normal, :exclusive])
    end

    def launcher(arg = nil)

    end

    def executors(arg = nil)
      set_or_return(:executors, arg, kind_of: Integer)
    end

    def labels(arg = nil)
      set_or_return(:labels, arg, kind_of: Array)
    end

    def config(arg = nil)
      set_or_return(:config, arg, kind_of: String)
    end

    #
    #
    #
    def exists?
      !!@exists
    end
  end
end

#
#
#
class Chef
  class Provider::JenkinsSlave < Provider
    class JobDoesNotExist < StandardError
      def initialize(job, action)
        super "The Jenkins job `#{job}` does not exist. In order to " \
              "#{action} `#{job}`, that job must first exist on the " \
              "Jenkins server!"
      end
    end

    require 'rexml/document'

    include Jenkins::Helper

    def load_current_resource
      Chef::Log.debug("Loading current resource #{new_resource}")

      @current_resource = Resource::JenkinsSlave.new(new_resource.name)
      @current_resource.name(new_resource.name)

      if current_slave
        @current_resource.exists = true
      end
    end

    #
    # This provider supports why-run mode.
    #
    def whyrun_supported?
      true
    end

    #
    # Register the current slave with the Jenkins master.
    #
    def action_create
    end

    #
    # Deletes this slave.
    #
    # @note This does not delete the node from Chef, just removes this node
    # from the Jenkins master as a builder.
    #
    def action_delete
      if current_slave.exists?
        converge_by("Delete #{new_resource}") do
          executor.execute!('delete-node', new_resource.name)
        end
      else
        Chef::Log.debug("#{new_resource} not created - skipping")
      end
    end

    private

    #
    # The job in the current, in XML format.
    #
    # @return [nil, Hash]
    #   nil if the job does not exist, or a hash of important information if
    #   it does
    #
    def current_slave
      return @current_slave if @current_slave

      Chef::Log.debug "Load #{new_resource} slave information"

      response = executor.execute('get-node', new_resource.name)
      return nil if response.nil? || response =~ /No such node/

      Chef::Log.debug "Parse #{new_resource} as XML"
      xml = REXML::Document.new(response)

      @current_slave = {}.tap do |h|
        h[:name]        = xml.elements['/slave/name'].text
        h[:description] = xml.elements['/slave/description'].text
        h[:remote_fs]   = xml.elements['/slave/numExecutors'].text.to_i
        h[:mode]        = xml.elements['/slave/mode'].text
        h[:executors]   = xml.elements['/slave/remoteFS'].text
        h[:launcher]    = xml.elements['/slave/launcher'].attributes['class'] # todo transform this
        h[:labels]      = xml.elements['/slave/label'].text.split(' ')
        h[:user_id]     = xml.elements['/slave/userId'].text
        h[:xml]         = xml
        h[:raw]         = response
      end

      @current_slave
    end
  end
end
