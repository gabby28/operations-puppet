class role::phabricator::config {
    #Both app and admin user are limited to the appropriate
    #database based on the connecting host.
    include passwords::mysql::phabricator
    $mysql_adminuser = $passwords::mysql::phabricator::admin_user
    $mysql_adminpass = $passwords::mysql::phabricator::admin_pass
    $mysql_appuser = $passwords::mysql::phabricator::app_user
    $mysql_apppass = $passwords::mysql::phabricator::app_pass
    $mysql_maniphestuser = $passwords::mysql::phabricator::manifest_user
    $mysql_maniphestpass = $passwords::mysql::phabricator::manifest_pass
}
# phabricator instance for legalpad.wikimedia.org
class role::phabricator::legalpad {
    include role::phabricator::config

    system::role { 'role::phabricator::legalpad':
        description => 'Phabricator (Legalpad)'
    }

    $current_tag = 'fabT440'
    class { '::phabricator':
        git_tag                  => $current_tag,
        lock_file                => '/var/run/phab_repo_lock',
        mysql_admin_user         => $role::phabricator::config::mysql_adminuser,
        mysql_admin_pass         => $role::phabricator::config::mysql_adminpass,
        auth_type                => 'sul',
        settings                 => {
            'darkconsole.enabled'       => false,
            'phabricator.base-uri'      => 'https://legalpad.wikimedia.org',
            'mysql.user'                => $role::phabricator::config::mysql_appuser,
            'mysql.pass'                => $role::phabricator::config::mysql_apppass,
            'mysql.host'                => 'm3-master.eqiad.wmnet',
            'storage.default-namespace' => 'phlegal',
            'phpmailer.smtp-host'       =>
                inline_template('<%= @mail_smarthost.join(";") %>'),
            'metamta.default-address'   =>
                'no-reply@legalpad.wikimedia.org',
            'metamta.domain'            => 'legalpad.wikimedia.org',
        },
    }

    # no 443 needed, we are behind misc. varnish
    ferm::service { 'phablegal_http':
        proto   => 'tcp',
        port    => '80',
    }
}

# production phabricator instance
class role::phabricator::main {
    include role::phabricator::config

    system::role { 'role::phabricator::main':
        description => 'Phabricator (Main)'
    }

    #let's go jenkins
    $current_tag = 'T77082'
    $domain = 'phabricator.wikimedia.org'
    $altdom = 'phab.wmfusercontent.org'
    $mysql_host = 'm3-master.eqiad.wmnet'

    class { '::phabricator':
        git_tag          => $current_tag,
        lock_file        => '/var/run/phab_repo_lock',
        mysql_admin_user => $role::phabricator::config::mysql_adminuser,
        mysql_admin_pass => $role::phabricator::config::mysql_adminpass,
        auth_type        => 'dual',
        sprint_tag       => '0.6.1.4',
        security_tag     => 'T518.1',
        libraries        => ['/srv/phab/libext/Sprint/src'],
        extension_tag    => 'HEAD',
        extensions       => [ 'MediaWikiUserpageCustomField.php',
                              'LDAPUserpageCustomField.php',
                              'SecurityPolicyEnforcerAction.php'],
        settings         => {
            'search.elastic.host'                       => 'http://search.svc.eqiad.wmnet:9200',
            'search.elastic.namespace'                  => 'phabricatormain',
            'storage.upload-size-limit'                 => '10M',
            'darkconsole.enabled'                       => false,
            'phabricator.base-uri'                      => "https://${domain}",
            'security.alternate-file-domain'            => "https://${altdom}",
            'mysql.user'                                => $role::phabricator::config::mysql_appuser,
            'mysql.pass'                                => $role::phabricator::config::mysql_apppass,
            'mysql.host'                                => $mysql_host,
            'phpmailer.smtp-host'                       => inline_template('<%= @mail_smarthost.join(";") %>'),
            'metamta.default-address'                   => "no-reply@${domain}",
            'metamta.domain'                            => $domain,
            'metamta.maniphest.reply-handler-domain'    => $domain,
            'metamta.maniphest.public-create-email'     => "task@${domain}",
            'metamta.reply-handler-domain'              => $domain,
            'repository.default-local-path'             => '/srv/phab/repos',
            'phd.start-taskmasters'                     => 10,
        },
    }

    class { 'exim::roled':
        local_domains           => [ '+system_domains', '+phab_domains' ],
        enable_mail_relay       => false,
        enable_external_mail    => false,
        smart_route_list        => $::mail_smarthost,
        enable_mailman          => false,
        phab_relay              => true,
        enable_spamassassin     => false,
    }

    include passwords::phabricator
    $emailbotcert = $passwords::phabricator::emailbot_cert

    include phabricator::monitoring

    class { '::phabricator::mailrelay':
        default          => {
            security     => 'users',
            maint        => false,
            taskcreation => "task@${domain}",
        },
        address_routing => {
            ulsfo    => 'ops-ulsfo',
            codfw    => 'ops-codfw',
            pmtpa    => 'ops-pmtpa',
            esams    => 'ops-esams',
            eqiad    => 'ops-eqiad',
            core-ops => 'ops-core',
            network  => 'ops-network',
            ops-requests => 'operations',
            testproj     => 'demoproject'
        },
        phab_bot        => {
            root_dir    => '/srv/phab/phabricator/',
            username    => 'emailbot',
            host        => "https://${domain}/api/",
            certificate => $emailbotcert,
        },
    }

    ferm::service { 'phabmain_http':
        proto    => 'tcp',
        port     => '80',
    }

    ferm::service { 'phabmain_https':
        proto    => 'tcp',
        port     => '443',
    }

    # receive mail from mail smarthosts
    ferm::service { 'phabmain-smtp':
        port     => '25',
        proto    => 'tcp',
        srange   => inline_template('(<%= @mail_smarthost.map{|x| "@resolve(#{x})" }.join(" ") %>)'),
    }

    # redirect bugzilla URL patterns to phabricator
    # handles translation of bug numbers to maniphest task ids
    phabricator::redirector { "redirector.${domain}":
        mysql_user    => $role::phabricator::config::mysql_maniphestuser,
        mysql_pass    => $role::phabricator::config::mysql_maniphestpass,
        mysql_host    => $mysql_host,
        rootdir       => '/srv/phab',
        field_index   => '4rRUkCdImLQU',
        phab_host     => $domain,
        alt_host      => $altdom,
    }

    # community metrics mail (RT #3962, T1003)
    phabricator::logmail {'communitymetrics':
        script_name  => 'community_metrics.sh',
        rcpt_address => 'communitymetrics@wikimedia.org',
        sndr_address => 'communitymetrics@wikimedia.org',
        monthday     => '1',
    }
}

# phabricator instance on wmflabs at phab-01.wmflabs.org
class role::phabricator::labs {

    #pass not sensitive but has to match phab and db
    $mysqlpass = 'labspass'
    $current_tag = 'T77082'
    class { '::phabricator':
        git_tag          => $current_tag,
        lock_file        => '/var/run/phab_repo_lock',
        auth_type        => 'local',
        libext_tag       => '0.6.1.4',
        libraries        => {
              'sprint'   => '/srv/phab/libext/Sprint/src',
        },
        extension_tag    => 'HEAD',
        extensions       => ['SecurityPolicyEnforcerAction.php'],
        settings         => {
            'search.elastic.host'             => 'http://localhost:9200',
            'search.elastic.namespace'        => 'phabricator',
            'darkconsole.enabled'             => true,
            'phabricator.base-uri'            => "https://${::hostname}.wmflabs.org",
            'mysql.pass'                      => $mysqlpass,
            'auth.require-email-verification' => false,
        },
    }

    package { 'mysql-server': ensure => present }

    class { 'mysql::config':
        root_password => $mysqlpass,
        sql_mode      => 'STRICT_ALL_TABLES',
        restart       => true,
        require       => Package['mysql-server'],
    }

    service { 'mysql':
        ensure     => running,
        hasrestart => true,
        hasstatus  => true,
        require    => Package['mysql-server'],
    }
    package { 'openjdk-7-jre-headless':
        ensure => present,
    }

    package { 'elasticsearch':
        ensure         => present,
        require        => Package['openjdk-7-jre-headless'],
    }

    service { 'elasticsearch':
        ensure     => running,
        hasrestart => true,
        hasstatus  => true,
        require    => Package['elasticsearch'],
    }

    # dummy redirector to test out the redirect patterns for bugzilla
    phabricator::redirector { 'redirector.fab-01.wmflabs.org':
        mysql_user    => 'root',
        mysql_pass    => $mysqlpass,
        mysql_host    => 'localhost',
        rootdir       => '/srv/phab',
        field_index   => 'yERhvoZPNPtM',
        phab_host     => 'phab-01.wmflabs.org',
        alt_host      => 'phab-01.wmflabs.org',
    }

}
