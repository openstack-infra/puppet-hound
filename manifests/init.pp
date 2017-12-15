# Class to configure hound
#
# == Class: hound
class hound (
  $config_json   = 'hound/config.json',
  $datadir       = '/home/hound/data',
  $manage_config = true,
  $www_base      = '/var/www/',
  $serveradmin   = "webmaster@${::fqdn}",
  $serveraliases = undef,
  $vhost_name    = $::fqdn,
  $ulimit_max_open_files = 2048,
  $git_source_uri = 'git://github.com/etsy/Hound.git',
) {

  $docroot = "${www_base}/hound"

  file { $www_base:
    ensure => directory,
    owner  => root,
    group  => root,
  }

  file { $docroot:
    ensure  => directory,
    owner   => root,
    group   => root,
    require => [
      File[$www_base],
    ]
  }

  package { 'golang':
    ensure => present,
  }

  user { 'hound':
    ensure     => present,
    home       => '/home/hound',
    shell      => '/bin/bash',
    gid        => 'hound',
    managehome => true,
    require    => Group['hound'],
  }

  group { 'hound':
    ensure => present,
  }

  file {'/home/hound':
    ensure  => directory,
    owner   => 'hound',
    group   => 'hound',
    mode    => '0755',
    require => User['hound'],
  }

  file { $datadir:
    ensure  => 'directory',
    owner   => 'hound',
    group   => 'hound',
    require => User['hound'],
  }

  if $manage_config {
    file { '/home/hound/config.json':
      ensure  => 'present',
      owner   => 'hound',
      group   => 'hound',
      content => file($config_json),
      require => User['hound'],
    }
  }

  vcsrepo { '/home/hound/src/github.com/etsy/hound':
    ensure   => latest,
    provider => git,
    source   => $git_source_uri,
    notify   => Exec['build_hound'],
  }

  exec { 'build_hound':
    command     => 'go install github.com/etsy/hound/cmds/...',
    path        => '/bin:/usr/bin:/usr/local/bin',
    environment => 'GOPATH=/home/hound',
    cwd         => '/home/hound',
    creates     => '/home/hound/bin/houndd',
    user        => 'hound',
    timeout     => 600,
    require     => [
      User['hound'],
      Package['golang'],
    ]
  }

  service { 'hound':
    ensure     => running,
    hasrestart => true,
    require    => [
      File['/etc/init.d/hound'],
      Exec['build_hound'],
    ],
    subscribe  => File['/home/hound/config.json'],
  }

  file { '/etc/init.d/hound':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0755',
    content => template('hound/hound.init.erb'),
    notify  => Service['hound'],
    before  => Service['hound'],
  }

  include ::httpd

  httpd::mod { 'rewrite':
    ensure => present,
    before => Service['hound'],
  }

  httpd::mod { 'proxy':
    ensure => present,
    before => Service['hound'],
  }

  httpd::mod { 'proxy_http':
    ensure => present,
    before => Service['hound'],
  }

  httpd::vhost { $vhost_name:
    port     => 80,
    docroot  => $docroot,
    priority => '50',
    template => 'hound/hound.vhost.erb',
    require  => File[$docroot],
  }

  file { "${docroot}/503.html":
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('hound/503.html.erb'),
    require => File[$docroot],
  }

  file { '/var/log/hound.log':
    owner   => 'hound',
    group   => 'hound',
    mode    => '0644',
    require => User['hound'],
  }

  logrotate::file { 'houndlog':
    ensure  => present,
    log     => '/var/log/hound.log',
    options => ['compress',
      'copytruncate',
      'delaycompress',
      'missingok',
      'rotate 7',
      'daily',
      'notifempty',
    ],
  }

}
