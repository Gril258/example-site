# internal_network
class internal_network (
  $location,
  $internal_ip = $::ipaddress_eth1,
  $vpn_route = 'yes',
) {

  host { 'hosts-localhost':
    ensure => 'present',
    ip     => '127.0.0.1',
    name   => 'localhost'
  }

  host { 'hosts-fqdn':
    ensure => 'present',
    ip     => $internal_ip,
    name   => $::fqdn
  }


  case $location {
    'example': {
      $host_override_list = {
        'hosts-example.foo.bar' => {
          ip     => '172.16.100.11',
          name   => 'example.foo.bar'
        },
      }
      if $::fqdn != "openvpn.infra.${location}" and $vpn_route == 'yes'{
        $route_list = {
          'to-vpn' => {
            'subnet'  => '10.10.0.0/16',
            'gateway' => '192.168.60.1',
            'device'  => ''
          },
          'to-mobile-vpn' => {
            'subnet'  => '10.11.0.0/16',
            'gateway' => '192.168.60.1',
            'device'  => ''
          },
          'to-dmz' => {
            'subnet'  => '192.168.100.0/24',
            'gateway' => '10.10.0.1',
            'device'  => ''
          },
        }
        create_resources(internal_network::route, $route_list)
      }
    }
    default: {
      fail("no location specific data provided for ${location}")
    }
  }

  $host_override_defauts = {
    'ensure' => present,
  }

  create_resources('host', $host_override_list, $host_override_defauts)

  @@dnsmasq::hostrecord { $::fqdn:
    ip => $internal_ip
  }
  @@dnsmasq::address { $::fqdn:
    ip => $internal_ip
  }
  @@::powerdns::a { $::fqdn:
    ip => $internal_ip
  }
  @@::powerdns::ptr { $::fqdn:
    ip => $internal_ip
  }
}

define internal_network::route (
  $subnet,
  $gateway,
  $device = '',
  ) {

  service { "openvpn-route-${name}":
    ensure     => running,
    provider   => 'base',
    enable     => true,
    start      => "ip route add ${subnet} via ${gateway} ${device}",
    status     => "ip route list |grep -o -E \"${subnet} via ${gateway} ${device}\"",
    stop       => "ip route del ${subnet} via ${gateway} ${device}",
    hasrestart => false,
    hasstatus  => true,
  }

  file { "/etc/network/if-up.d/openvpn-route-${name}":
    ensure  => file,
    mode    => '0755',
    content => "ip route add ${subnet} via ${gateway} ${device}",
  }
}
