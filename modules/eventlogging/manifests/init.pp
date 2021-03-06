# == Class: eventlogging
#
# EventLogging is a platform for modeling, logging and processing
# arbitrary analytic data. This Puppet module manages the configuration
# of its event-processing back end.
#
# The back end comprises a suite of service types, each of which
# implements a different task:
#
# [forwarders]    Read line-oriented data via UDP and publish it on a
#                 ZeroMQ TCP socket with the same port number.
#
# [processors]    Decode raw, streaming log data into strictly-validated
#                 JSON objects.
#
# [multiplexers]  Selects multiple ZeroMQ publisher streams into a
#                 single stream.
#
# [consumers]     Data sinks. Consumers subscribe to the parsed and
#                 validated event stream and write it to some medium.
#
# [reporter]      Specialized StatsD clients which report counts of all
#                 incoming events (valid and invalid) to a StatsD host.
#
# These services communicate with one another using a publisher /
# subscriber model using ØMQ as the transport layer. Different
# event-processing patterns can be implemented by freely composing
# multiple instances of each type, running locally or distributed across
# several hosts.
#
# The /etc/eventlogging.d file hierarchy contains instance definitions.
# It has a subfolder for each service type. An Upstart task,
# 'eventlogging/init', walks this file hierarchy and provisions a
# job for each instance definition. Instance definition files contain
# command-line arguments for the service program, one argument per line.
#
# An 'eventloggingctl' shell script provides a convenient wrapper around
# Upstart's initctl that is specifically tailored for managing
# EventLogging tasks.
#
class eventlogging {
    include ::eventlogging::package

    $log_dir = '/srv/log/eventlogging'

    # We ensure the /srv/log (parent of $log_dir) manually here, as
    # there is no proper class to rely on for this, and starting a
    # separate would be an overkill for now.
    if !defined(File['/srv/log']) {
        file { '/srv/log':
            ensure  => 'directory',
            mode    => '755',
            owner   => 'root',
            group   => 'root',
        }
    }

    group { 'eventlogging':
        ensure => present,
    }

    user { 'eventlogging':
        ensure     => present,
        gid        => 'eventlogging',
        shell      => '/bin/false',
        home       => '/nonexistent',
        system     => true,
        managehome => false,
    }

    # Instance definition files.
    file { [
        '/etc/eventlogging.d',
        '/etc/eventlogging.d/consumers',
        '/etc/eventlogging.d/forwarders',
        '/etc/eventlogging.d/multiplexers',
        '/etc/eventlogging.d/processors',
        '/etc/eventlogging.d/reporters'
    ]:
        ensure  => directory,
        recurse => true,
        purge   => true,
        force   => true,
        before => File['/etc/init/eventlogging'],
    }

    # Manage EventLogging services with 'eventloggingctl'.
    # Usage: eventloggingctl {start|stop|restart|status|tail}
    file { '/sbin/eventloggingctl':
        source => 'puppet:///modules/eventlogging/eventloggingctl',
        mode   => '0755',
    }

    # Upstart job definitions.
    file { '/etc/init/eventlogging':
        source  => 'puppet:///modules/eventlogging/init',
        recurse => true,
        purge   => true,
        force   => true,
    }

    # 'eventlogging/init' is the master upstart task; it walks
    # </etc/eventlogging.d> and starts a job for each instance
    # definition file that it encounters.
    service { 'eventlogging/init':
        provider => 'upstart',
        require  => [
            File['/etc/init/eventlogging'],
            User['eventlogging']
        ],
    }

    # Plug-ins placed in this directory are loaded automatically.
    file { '/usr/local/lib/eventlogging':
        ensure => directory,
    }

    # Logs are collected in <$log_dir> and rotated daily.
    file { [ $log_dir, "${log_dir}/archive" ]:
        ensure  => directory,
        owner   => 'eventlogging',
        group   => 'eventlogging',
        mode    => '0664',
    }

    # Link logs to /var/log/eventlogging, so people can find it in a
    # more prominent place too.
    if ( $log_dir != '/var/log/eventlogging' ) {
        file { '/var/log/eventlogging':
            ensure  => 'link',
            target  => $log_dir,
        }
    }

    file { '/etc/logrotate.d/eventlogging':
        content => template('eventlogging/logrotate.erb'),
        require => File["${log_dir}/archive"],
        mode    => '0444',
    }
}
