# == Class: ipython
#
# Base class for IPython setups. IPython is an interactive interpreter for
# Python which provides facilities for scientific computing, such as
# distributed computation and graphical development environment.
#
# Note that in most cases, rather than including this class directly, you will
# want to simply accept the defaults and skip directly to including a specific
# IPython service, such as 'ipython::notebook'.
#
# === Parameters
#
# [*ipythondir*]
#   IPython working directory. Equivalent to the IPYTHONDIR environment
#   variable. Defaults to '/srv/ipython'.
#
# [*user*]
#   Any IPython services will run under this user's uid. The user account will
#   be created if it does not already exist. Defaults to 'ipython'.
#
# [*group*]
#   Run services under this gid. Will be created if it does not already exist.
#   Defaults to 'ipython'.
#
# === Authors
#
# Ori Livneh <ori@wikimedia.org>
#
# === Copyright
#
# Copyright (C) 2013 Ori Livneh
# Licensed under the GNU Public License, version 2
#
class ipython(
    $ipythondir = '/srv/ipython',
    $user       = 'ipython',
    $group      = 'ipython'
) {
    package { 'ipython':
        ensure => latest,
    }

    user { $user:
        ensure     => present,
        gid        => $group,
        shell      => '/bin/false',
        home       => '/nonexistent',
        managehome => false,
        system     => true,
    }

    group { $user:
        ensure => present,
    }

    file { $ipythondir:
        ensure => directory,
        owner  => $user,
        group  => $group,
        mode   => '0755',
    }
}
