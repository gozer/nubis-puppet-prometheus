class nubis_prometheus::backup {
  file { '/usr/local/bin/nubis-prometheus-backup':
    ensure => file,
    owner  => root,
    group  => root,
    mode   => '0755',
    source => "puppet:///modules/${module_name}/backup",
  }
}
