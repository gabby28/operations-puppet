# == Class: mediawiki::packages::hhvm
#
# Installs all the packages needed for a working hhvm installation.
#
# This class should be directly included wherever you need hhvm to run.
# It works on Trusty and newer distros.
#
class mediawiki::packages::hhvm {
    package { [ 'hhvm', 'hhvm-luasandbox', 'hhvm-fss', 'hhvm-wikidiff2' ]:
        # For now, we want to always install the latest and the shiniest
        ensure => latest
    }
}