# Class: toollabs::submit
#
# This role sets up an submit host instance in the Tool Labs model.
# (A host that can only be used to submit jobs; presently used by
# tools-submit which runs bigbrother and the gridwide cron.
#
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
class toollabs::submit inherits toollabs {

    include gridengine::submit_host,
            toollabs::exec_environ,
            toollabs::hba

    file { '/etc/ssh/ssh_config':
        ensure => file,
        mode   => '0444',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/toollabs/submithost-ssh_config',
    }

    motd::script { 'submithost-banner':
        ensure   => present,
        source   => "puppet:///modules/toollabs/40-${::instanceproject}-submithost-banner",
    }

    file { "${toollabs::store}/submithost-${::fqdn}":
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        require => File[$toollabs::store],
        content => "${::ipaddress}\n",
    }

    package { 'misctools':
        ensure => latest,
    }

    file { '/usr/local/sbin/bigbrother':
        ensure => file,
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
        source => 'puppet:///modules/toollabs/bigbrother',
    }

    file { '/etc/init/bigbrother.conf':
        ensure => file,
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
        source => 'puppet:///modules/toollabs/bigbrother.conf',
    }

    service { 'bigbrother':
        ensure  => running,
        require => File['/usr/local/sbin/bigbrother', '/etc/init/bigbrother.conf'],
    }
}
