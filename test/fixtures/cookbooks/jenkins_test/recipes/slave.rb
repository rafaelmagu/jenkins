include_recipe 'jenkins::server'

#
# Execute a command
#
jenkins_slave 'my-slave'
