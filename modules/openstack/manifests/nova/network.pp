class openstack::nova::network($openstack_version=$::openstack::version, $novaconfig) {
    include openstack::repo

    package {  [ "nova-network", "dnsmasq" ]:
        ensure  => present,
        require => Class["openstack::repo"];
    }

    service { "nova-network":
        ensure    => running,
        subscribe => File['/etc/nova/nova.conf'],
        require   => Package["nova-network"];
    }

    # dnsmasq is run manually by nova-network, we don't want the service running
    service { "dnsmasq":
        enable  => false,
        ensure  => stopped,
        require => Package["dnsmasq"];
    }

    $nova_dnsmasq_aliases = {
        # eqiad
        'deployment-cache-text02'   => {public_ip  => '208.80.155.135',
                                        private_ip => '10.68.16.16' },
        'deployment-cache-upload02' => {public_ip  => '208.80.155.136',
                                        private_ip => '10.68.17.51' },
        'deployment-cache-bits01'   => {public_ip  => '208.80.155.137',
                                        private_ip => '10.68.16.12' },
        'deployment-stream'         => {public_ip  => '208.80.155.138',
                                        private_ip => '10.68.17.106' },
        'deployment-cache-mobile03' => {public_ip  => '208.80.155.139',
                                        private_ip => '10.68.16.13' },
        'tools-webproxy'            => {public_ip  => '208.80.155.131',
                                        private_ip => '10.68.16.4' },
        'udplog'                    => {public_ip  => '208.80.155.191',
                                        private_ip => '10.68.16.58' },

        # A wide variety of hosts are reachable via a public web proxy.
        'labs_shared_proxy' => {public_ip  => '208.80.155.156',
                                private_ip => '10.68.16.65'},
    }

    file { '/etc/dnsmasq-nova.conf':
        content => template("openstack/${$openstack_version}/nova/dnsmasq-nova.conf.erb"),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
    }

    sysctl::parameters { 'openstack':
        values => {
            # Turn off IP filter
            'net.ipv4.conf.default.rp_filter' => 0,
            'net.ipv4.conf.all.rp_filter'     => 0,

            # Enable IP forwarding
            'net.ipv4.ip_forward'         => 1,
            'net.ipv6.conf.all.forwarding'    => 1,

            # Disable RA
            'net.ipv6.conf.all.accept_ra'     => 0,
        },
        priority => 50,
    }
}
