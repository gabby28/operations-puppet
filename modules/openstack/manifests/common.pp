class openstack::common(
            $novaconfig,
            $instance_status_wiki_host,
            $instance_status_wiki_domain,
            $instance_status_wiki_page_prefix,
            $instance_status_wiki_region,
            $instance_status_dns_domain,
            $instance_status_wiki_user,
            $instance_status_wiki_pass,
            $openstack_version=$::openstack::version,
            ) {
    include openstack::repo

    package { [ 'nova-common', 'python-keystone' ]:
        ensure  => present,
        require => Class['openstack::repo'];
    }

    package { [ 'unzip', 'vblade-persist', 'python-mysqldb', 'bridge-utils', 'ebtables', 'mysql-common' ]:
        ensure  => present,
        require => Class['openstack::repo'];
    }

    require mysql

    # For IPv6 support
    package { [ 'python-netaddr', 'radvd' ]:
        ensure  => present,
        require => Class['openstack::repo'];
    }

    file {
        '/etc/nova/nova.conf':
            content => template("openstack/${$openstack_version}/nova/nova.conf.erb"),
            owner   => 'nova',
            group   => 'nogroup',
            mode    => '0440',
            require => Package['nova-common'];
    }

    file {
        '/etc/nova/api-paste.ini':
            content => template("openstack/${$openstack_version}/nova/api-paste.ini.erb"),
            owner   => 'nova',
            group   => 'nogroup',
            mode    => '0440',
            require => Package['nova-common'];
    }

    package { 'python-novaclient':
        ensure => present,
    }
}
