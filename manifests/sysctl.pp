class sysctl(
  $vm_swappiness = 0,
  $ipv4_forwarding = 0
) {

  file { '/etc/sysctl.d':
    ensure => directory,
  }

  file { '/etc/sysctl.d/sysctl-defaults.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    content => template("/etc/puppet/environments/${environment}/templates/sysctl/sysctl-defaults.conf.erb"),
    notify  => Exec['sysctl-defaults-reload']
  }

  exec { 'sysctl-defaults-reload':
    command     => '/sbin/sysctl -p /etc/sysctl.d/sysctl-defaults.conf',
    user        => 'root',
    refreshonly => true,
  }

}
