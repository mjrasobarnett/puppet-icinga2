define icinga2::server::pgsql_db (
  $db_name = $title,
  $db_user,
  $db_password,
) {
  postgresql::server::db { $db_name :
      user     => $db_user,
      password => postgresql_password($db_user, $db_password),
      require  => Class['postgresql::server'],
  }
  postgresql::server::pg_hba_rule { "$db_name allow $db_user":
    type        => 'local',
    database    => $db_name,
    user        => $db_user,
    auth_method => 'md5',
    order       => '001',
  }
  postgresql::server::pg_hba_rule { "$db_name allow $db_user localhost ipv4":
    type        => 'host',
    database    => $db_name,
    user        => $db_user,
    address     => '127.0.0.1/32',
    auth_method => 'md5',
    order       => '001',
  }
  postgresql::server::pg_hba_rule { "$db_name allow $db_user localhost ipv6":
    type        => 'host',
    database    => $db_name,
    user        => $db_user,
    address     => '::1/128',
    auth_method => 'md5',
    order       => '001',
  }
}

