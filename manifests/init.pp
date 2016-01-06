# Class to configure hound
#
# == Class: hound
class hound (
  $manage_config = true,
  $config_json = 'hound/config.json',
  $vhost_name = $::fqdn,
  $datadir = '/home/hound/data',
  $serveradmin = "webmaster@${::fqdn}",
) {

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
    source   => 'git://github.com/etsy/Hound.git',
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
    ensure => file,
    owner  => root,
    group  => root,
    mode   => '0755',
    source => 'puppet:///modules/hound/hound.init',
    notify => Service['hound'],
    before => Service['hound'],
  }

  include ::httpd

  httpd_mod { 'rewrite':
    ensure => present,
    before => Service['hound'],
  }

  httpd_mod { 'proxy':
    ensure => present,
    before => Service['hound'],
  }

  httpd_mod { 'proxy_http':
    ensure => present,
    before => Service['hound'],
  }

  httpd::vhost { $vhost_name:
    port     => 80,
    docroot  => 'MEANINGLESS ARGUMENT',
    priority => '50',
    template => 'hound/hound.vhost.erb',
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
