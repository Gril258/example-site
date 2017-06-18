class common (
    $env,
    $location
  ) {

  Exec { path => '/bin:/sbin:/usr/bin:/usr/sbin' }

  if ($::operatingsystem == 'Debian' and $::lsbmajdistrelease >= 8) {
    $emacs_name = 'emacs-nox'
  } else {
    $emacs_name = 'emacs23-nox'
  }



# remove content from default source list
  class { 'apt':
    purge_preferences => true,
  }

  case $::lsbdistcodename {
    'jessie': {
      apt::source { 'debian_stable':
        comment  => 'This is the main Debian stable',
        location => 'http://http.debian.net/debian/',
        release  => 'jessie',
        repos    => 'main contrib non-free',
        pin      => '600',
      }
    }
    'wheezy': {
      apt::source { 'debian_stable':
        comment  => 'This is the main Debian stable',
        location => 'http://http.debian.net/debian/',
        release  => 'wheezy',
        repos    => 'main contrib non-free',
        pin      => '600',
      }
    }
    default: {
      fail('unsupported major release')
    }
  }

  #apt::source { 'debian_stable_jessie_backports':
  #  comment  => 'This is the main Debian stable backports',
  #  location => 'http://http.debian.net/debian/',
  #  release  => 'jessie-backports',
  #  repos    => 'main contrib non-free',
  #  pin      => '-10',
  #}


  Package <| tag != 'special' |> {
    require +> Exec['apt-update-common']
  }

  case $location {
    'example': {
      exec { 'apt-update-common-special':
        command     => 'apt-get update || apt-get install -y apt-transport-https && apt-get update',
        refreshonly => true,
      }
      exec { 'apt-update-common':
        command => 'apt-get update || apt-get install -y apt-transport-https && apt-get update',
        require => Apt::Source['debian_stable']
      }
      $nameserver = '192.168.60.13'
    }
    default: {
      fail("no location specific data provided for ${location}")
    }
  }

  file { '/etc/resolv.conf':
    ensure  => present,
    mode    => '0644',
    content => template("/etc/puppet/environments/${environment}/templates/resolv.conf.erb"),
  }

  # All hosts trust each other when SSH connecting
  @@sshkey { $::fqdn:
    type         => dsa,
    host_aliases => [ $::ipaddress, $::hostname ],
    key          => $::sshdsakey,
    tag          => [ 'sshkey-all' ],
  }

  Sshkey <<| tag == 'sshkey-all'|>>

  package { [
    'vim', 'htop', 'iftop', 'jnettop', 'iotop', 'less', 'apt-file',
    'mlocate', 'tcpdump', 'screen', 'tmux', 'byobu', 'strace',
    'rsync', 'ncdu', 'bash-completion', 'dnsutils', 'aptitude',
    'unzip', 'openssh-server', $emacs_name, 'telnet', 'tree',
    'augeas-tools', 'libaugeas-ruby', 'logwatch', 'rdiff-backup',
    'cron', 'iputils-ping', 'man', 'file', 'bc', 'sysstat', 'traceroute',
    'apt-utils', 'git', 'ntp', 'lsof'
  ]: }

  # set up puppet agent
  if ($::fqdn != "puppet.infra.${location}") {
    class { '::puppetnode::agent':
      env    => $env,
      server => "puppet.infra.${location}"
    }
  }

  # administrators ssh keys

  ssh_authorized_key { 'yourkey':
    user => 'puppet',
    type => 'ssh-rsa',
    key  => 'public_key',
  }

  # set locales
  class { 'locales':
    default_locale => 'en_US.UTF-8',
    locales        => ['en_US.UTF-8 UTF-8', 'cs_CZ.UTF-8 UTF-8'],
  }

  # set up cron a bit
  unless defined(Package['cron']) {
    package { 'cron':
      ensure => 'latest',
    }
  }

  service { 'cron':
    ensure  => 'running',
    enable  => true,
    require => Package['cron'],
  }

  # disable mlocate
  file { '/etc/cron.daily/mlocate':
    mode    => '0644',
    require => Package['cron']
  }

  file { '/var/lib/mlocate/mlocate.db':
    ensure => 'absent'
  }
  # /disable mlocate

  # set localtime
  file { '/etc/localtime':
    ensure  => 'link',
    target  => '/usr/share/zoneinfo/Europe/Prague',
    force   => true,
    require => Class['locales']
  }

  user { 'root':
    ensure   => present,
    home     => '/root',
    shell    => '/bin/bash',
    password => '$6$eYsa1p5E$994CGt/tA2X5Oo49h4dv1Shh66b5L/U2crYzSNC3rfqiCSkEeQyuhU.3mI03OY1mQuPTEfYKGtCFtsQSlLiy31',
    uid      => '0',
    gid      => '0'
  }
}
