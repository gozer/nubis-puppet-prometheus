# Class: nubis_prometheus
# ===========================
#
# Full description of class nubis_prometheus here.
#
# Parameters
# ----------
#
# Document parameters here.
#
# * `sample parameter`
# Explanation of what this parameter affects and what it defaults to.
# e.g. "Specify one or more upstream ntp servers as an array."
#
# Variables
# ----------
#
# Here you should define a list of variables that this module would require.
#
# * `sample variable`
#  Explanation of how this variable affects the function of this class and if
#  it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#  External Node Classifier as a comma separated list of hostnames." (Note,
#  global variables should be avoided in favor of class parameters as
#  of Puppet 2.6.)
#
# Examples
# --------
#
# @example
#    class { 'nubis_prometheus':
#      servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#    }
#
# Authors
# -------
#
# Author Name <author@domain.com>
#
# Copyright
# ---------
#
# Copyright 2017 Your name here, unless otherwise noted.
#
class nubis_prometheus($version = '1.8.2', $blackbox_version = '0.7.0', $project=undef, $rules_dir) {

  if ($project) {
    $prometheus_project = $project
  }
  else {
    $prometheus_project = $::project_name
  }


  $prometheus_url = "https://github.com/prometheus/prometheus/releases/download/v${version}/prometheus-${version}.linux-amd64.tar.gz"
  $blackbox_url = "https://github.com/prometheus/blackbox_exporter/releases/download/v${blackbox_version}/blackbox_exporter-${blackbox_version}.linux-amd64.tar.gz"

  file { '/opt/prometheus':
    ensure => 'directory',
    owner  => 0,
    group  => 0,
    mode   => '0755',
  }

  file { '/etc/prometheus':
    ensure => 'directory',
    owner  => 0,
    group  => 0,
    mode   => '0755',
  }->file { '/etc/prometheus/rules.d':
    ensure  => 'directory',
    owner   => 0,
    group   => 0,
    mode    => '0755',
    recurse => true,
    source  => $rules_dir
  }->file { '/etc/prometheus/config.d':
    ensure => 'directory',
    owner  => 0,
    group  => 0,
    mode   => '0755',
  }

  file { '/var/lib/prometheus':
    ensure => 'directory',
    owner  => 0,
    group  => 0,
    mode   => '0755',
  }

  class { 'nubis_prometheus::backup':
    project => $project,
  }

  notice ("Grabbing prometheus ${version}")
  staging::file { "prometheus.${version}.tar.gz":
    source => $prometheus_url,
  }->
  staging::extract { "prometheus.${version}.tar.gz":
    strip   => 1,
    target  => '/opt/prometheus',
    creates => '/opt/prometheus/prometheus',
    require => File['/opt/prometheus'],
  }

  notice ("Grabbing blackbox ${blackbox_version}")
  staging::file { "blackbox.${blackbox_version}.tar.gz":
    source => $blackbox_url,
  }->
  staging::extract { "blackbox.${blackbox_version}.tar.gz":
    strip   => 1,
    target  => '/usr/local/bin',
    creates => '/usr/local/bin/blackbox_exporter',
  }

  file { '/etc/consul/svc-prometheus.json':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0644',
    content => template("${module_name}/svc-prometheus.json.tmpl"),
  }

  file { '/etc/confd/conf.d/prometheus.toml':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0644',
    content => template("${module_name}/prometheus.toml.tmpl"),
  }

  file { '/etc/confd/templates/prometheus.yml.tmpl':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0644',
    content => template("${module_name}/prometheus.yml.tmpl.tmpl"),
  }


  file { '/etc/confd/conf.d/blackbox.toml':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0644',
    content => template("${module_name}/blackbox.toml.tmpl"),
  }

  file { '/etc/confd/templates/blackbox.yml.tmpl':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0644',
    content => template("${module_name}/blackbox.yml.tmpl.tmpl"),
  }

systemd::unit_file { 'prometheus.service':
  source => 'puppet:///nubis/files/prometheus.systemd',
}
->service { 'prometheus':
  enable => true,
}

systemd::unit_file { 'blackbox.service':
  source => 'puppet:///nubis/files/blackbox.systemd',
}
->service { 'blackbox':
  enable => true,
}
