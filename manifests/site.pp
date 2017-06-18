# site.pp for example location

#
# Dynamic node definition
#

#node /^(machine_type)([0-9]+)\.(env)\.([a-z]+)$/ {
#  # global variables
#  $machine_type = $1
#  $machine_id = $2
#  $env = $3
#  $location = $4
#
#  # node specific data
#
#  # node classes
#
#  class { 'common':
#    env => $env,
#  }
#  class { 'internal_network':
#    location    => $location,
#  }
#
#  # node resources
#
#}

#
# default node
#

node 'default' {
  notify { 'Puppet does not know my node definition contact admin@world.cz': }
}

node /^(openvpn)\.(infra)\.([a-z]+)$/ {
  # global variables
  $machine_type = $1
  $machine_id = undef
  $env = $2
  $location = $3

  # node specific data
  case $location {
    'example': {
      $openvpn_server_list = {
        'example_dev_tap' => {
          'ca_key_country' => 'CZ',
          'ca_key_province' => 'CZ',
          'ca_key_city' => 'Your city',
          'ca_key_org' => 'Mr Responsible',
          'ca_key_email' => 'example@gmail.com',
          'ca_name' => 'yourdomain.cz',
          'remote' => 'openvpn.',
          'device'   => 'tap',
          'device_id' => '0',
          'br_device' => 'br2',
          'server_ip' => '10.10.0.1',
          'port' => '1194',
          'netmask' => '255.255.0.0',
          'pool_start' => '10.10.0.10',
          'pool_end' => '10.10.0.210',
          'user' => 'nobody',
          'group' => 'nogroup',
          'max_clients' => '200',
          'push_dns_ip' => '192.168.60.13',
          'push_route' => [
            { 'ip' => '192.168.60.0', 'netmask' => '255.255.255.0' },
            { 'ip' => '192.168.100.0', 'netmask' => '255.255.255.0'}
          ]
        },
      }
      $openvpn_client_list = {
        'client_ipg_tap' => {
          'remote' => 'openvpn.ipg.cloud',
          'port' => '1194',
          'certname' => "${location}@ipg.cloud",
          'server_ip' => '10.51.254.98',
          'device' => 'tap',
          'br_device' => 'br3',
          'device_id' => '1',
        }
      }
      create_resources(openvpn::client, $openvpn_client_list)
    }
    default: {
      fail("no location specific data provided for ${location}")
    }
  }

  # node classes

  class { 'common':
    env      => $env,
    location => $location,
  }

  class { 'internal_network':
    location    => $location,
  }

  class { 'sysctl':
    vm_swappiness   => pick($vm_swappiness, '0'),
    ipv4_forwarding => 1,
  }

  include openvpn
  #include zabbix::agent

  #node resources
  Ssh_authorized_key <<| tag == 'backup_root_authkey' |>>


  create_resources(openvpn::server, $openvpn_server_list)
}

node /^(puppet)\.(infra)\.([a-z]+)$/ {
  # global variables
  $machine_type = $1
  $machine_id = undef
  $env = $2
  $location = $3

  # node specific data

  # for direct puppet repo control
  ssh_authorized_key { 'yourkey':
    user => 'puppet',
    type => 'ssh-rsa',
    key  => 'public_key',
  }

  user { 'puppet':
    ensure => present,
    home   => '/var/lib/puppet',
    shell  => '/bin/bash',
  }

  file { '/var/lib/puppet/.ssh':
    ensure  => directory,
    owner   => 'puppet',
    require => User['puppet'],
  }

  # node classes

  class { 'common':
    env      => $env,
    location => $location,
  }

  class { 'internal_network':
    location    => $location,
  }

  include ::puppetnode::master

  #node resources
}

node /^(dns)([0-9]+)\.(infra)\.([a-z]+)$/ {
  # global variables
  $machine_type = $1
  $machine_id = $2
  $env = $3
  $location = $4

  # node specific data

  # for each location ve use local dns and remote one to other locations
  case $location {
    'example': {
      $forward_zones = 'example=127.0.0.1:10053, 10.in-addr.arpa=127.0.0.1:10053, 168.192.in-addr.arpa=127.0.0.1:10053'
      $zone_list = {
        '10.in-addr.arpa' => {},
        '168.192.in-addr.arpa' => {},
        'example' => {},
      }
    }
    default: {
      fail("no location specific data provided for ${location}")
    }
  }

  # node classes

  class { 'common':
    env      => $env,
    location => $location,
  }

  class { 'internal_network':
    location    => $location,
  }

  # dont need that now
  #class { 'powerdns_static':
  #  location => $location,
  #}

  class { 'powerdns':
    forward_zones    => $forward_zones,
    recursor_address => $::ipaddress,
    server_address   => $::ipaddress,
    max_cache_ttl    => 7200,
    zone_list        => $zone_list,
  }
}

node /^(hyp)([0-9]+)\.(infra)\.([a-z]+)$/ {
  # global variables
  $machine_type = $1
  $machine_id = $2
  $env = $3
  $location = $4

  # node specific data
  case $machine_id {
    '11': {
      $private_ip = '10.10.0.11'
      $public_ip = '192.168.100.11'
      $public_gw = '192.168.100.1'
      $container_list = {
        'openvpn.infra.example' => {
          'ensure' => 'running',
          'lxcpath' => '/var/lib/lxc',
          'public_network' => 'yes',
          'public_ip' => '192.168.100.14/24',
          'public_gw' => '192.168.100.254',
          'private_network' => 'yes',
          'private_ip' => '10.10.0.1/16',
          'private_gw' => $private_ip,
          'allow_tun' => 'yes',
          'autostart' => '1'
        },
        'puppet.infra.example' => {
          'ensure' => 'running',
          'lxcpath' => '/var/lib/lxc',
          'private_network' => 'yes',
          'private_ip' => '10.10.0.5/16',
          'private_gw' => $private_ip,
          'release' => 'jessie',
          'allow_tun' => 'yes',
          'autostart' => '1'
        },
        'dns1.infra.example' => {
          'ensure' => 'running',
          'lxcpath' => '/var/lib/lxc',
          'private_network' => 'yes',
          'private_ip' => '10.10.0.2/16',
          'private_gw' => $private_ip,
          'allow_tun' => 'yes',
          'autostart' => '1'
        },
      }
    }
    default: {
      fail {'no container data':}
    }
  }

  $container_defaults = {
    'ensure' => 'stopped',
    'private_network' => 'no',
    'public_network' => 'no',
    'template' => 'debian',
    'release' => 'jessie',
  }


  # node classes

  class { 'common':
    env      => $env,
    location => $location
  }

  class { 'internal_network':
    location    => $location,
    internal_ip => $private_ip,
  }

  class { 'lxc':
    public_bridge     => 'br0',
    public_macvlan    => 'mvlan0',
    public_interface  => 'eth0',
    public_ip         => $public_ip, # DMZ or public ip
    public_nm         => '255.255.255.0',
    public_gw         => '192.168.100.254',
    public_vlanid     => '10',
    public_vlan       => 'no',
    private_bridge    => 'br1',
    private_macvlan   => 'mvlan1',
    private_ip        => $private_ip,
    private_nm        => '255.255.255.0',
    private_vlanid    => '15',
    private_vlan      => 'no',
    private_interface => 'eth1',
    #public_alias      => [
    #  {
    #    id      => '1',
    #    ip      => '1.2.3.4',
    #    netmask => '255.255.255.248',
    #  }
    #],
  }

  # node resources
  create_resources(lxc::container, $container_list, $container_defaults)

}


