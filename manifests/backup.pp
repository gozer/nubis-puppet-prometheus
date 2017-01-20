class nubis_prometheus::backup($project,
  $duplicity_version = '0.7.11-0ubuntu0ppa1263~ubuntu14.04.1',
  $duply_version = '2.0.1',
  $boto_version  = '2.20.1-2ubuntu2',
  
  $max_age = '3M',
  $max_full_age = '1D',
  ) {

  file { '/usr/local/bin/nubis-prometheus-backup':
    ensure => file,
    owner  => root,
    group  => root,
    mode   => '0755',
    source => "puppet:///modules/${module_name}/backup",
  }

# Marker to recover from backups on boot only once per instance
# protecting ourselves from soft reboots
file { '/var/lib/prometheus/PRISTINE':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0644',
    content => 'Marker for initial boot of this image',
    require => [
      File['/var/lib/prometheus'],
    ]
}

cron::hourly { 'prometheus-backup':
    minute  => fqdn_rand(60),
    user    => 'root',
    command => "nubis-cron ${project}-prometheus-backup /usr/local/bin/nubis-prometheus-backup save",
}

# We want this cronjob to be 30 minutes offset from the backup one, just to avoid overlap
cron::daily { 'prometheus-backup-cleanup':
    minute  => ( fqdn_rand(60) + 30 ) % 60,
    # Run between midnight and 4 am
    hour    => fqdn_rand(4),
    user    => 'root',
    command => "nubis-cron ${project}-prometheus-backup-cleanup /usr/local/bin/nubis-prometheus-backup purge",
}

# Duplicity and Duply
apt::ppa {
  'ppa:duplicity-team/ppa':
}

package { 'python-boto':
  ensure => $boto_version,
}

package { 'duplicity':
  ensure  => $duplicity_version,
  require => [
    Apt::Ppa['ppa:duplicity-team/ppa'],
    Class['Apt::Update'],
    Package['python-boto'],
  ]
}

notice ("Grabbing duply ${duply_version}")
staging::file { "duply.${duply_version}.tgz":
  source => "https://sourceforge.net/projects/ftplicity/files/duply%20%28simple%20duplicity%29/2.0.x/duply_${duply_version}.tgz/download",
}->
staging::extract { "duply.${duply_version}.tgz":
  target  => '/usr/local/bin',
  strip   => 1,
  creates => '/usr/local/bin/duply',
}

file { [ '/etc/duply', '/etc/duply/prometheus' ]:
  ensure => 'directory',
  owner  => 'root',
  group  => 'root',
  mode   => '0700',
}

file { '/etc/duply/prometheus/exclude':
  ensure  => 'present',
  owner   => 'root',
  group   => 'root',
  mode    => '0600',
  require => [
    File['/etc/duply/prometheus'],
  ],
  content => '- /var/lib/prometheus/PRISTINE',
}

file { '/etc/duply/prometheus/conf':
  ensure  => 'present',
  owner   => 'root',
  group   => 'root',
  mode    => '0600',
  require => [
    File['/etc/duply/prometheus'],
  ],
  content => '
GPG_KEY="disabled"
TARGET="s3://s3-$(nubis-region).amazonaws.com/$(nubis-metadata NUBIS_PROMETHEUS_BUCKET)"
SOURCE="/var/lib/prometheus"
MAX_AGE=3M
MAX_FULLBKP_AGE=1D
DUPL_PARAMS="$DUPL_PARAMS --full-if-older-than $MAX_FULLBKP_AGE "
',
  }

}
