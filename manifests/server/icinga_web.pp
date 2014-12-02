class icinga2::server::icinga_web (
  $version,
  $web_db_name        = 'icinga_web',
  $web_db_user        = 'icinga_web',
  $web_db_password    = $db_password,
  $web_db_schema_path = "/usr/share/doc/icinga-web-${version}/schema",
  $webserver_root     = '/usr/share/icinga-web',
  $webserver_url,
) inherits icinga2::server {

  package { ['icinga-web', 'icinga-web-pgsql']:
    ensure  => $version,
  }

  icinga2::server::features::enable { 'command': }

  case $server_db_type {
    'pgsql': {
      icinga2::server::pgsql_db { $web_db_name :
        db_user     => $web_db_user,
        db_password => $web_db_password,
        notify      => Exec['import web schema'],
      }
      exec { 'import web schema':
        command     => "/bin/su - postgres -c 'export PGPASSWORD='\\''${db_password}'\\'' && psql -U ${web_db_user} -h localhost -d ${web_db_name} < ${web_db_schema_path}/pgsql.sql' && export PGPASSWORD='' && touch /etc/icinga-web/postgres_web_schema_loaded.txt",
        creates     => '/etc/icinga/postgres_web_schema_loaded.txt',
        refreshonly => true,
        require     => Icinga2::Server::Pgsql_db[ $web_db_name ],
      }
    }
    default: { fail("${server_db_type} is not supported!") }
  }

  # Not sure how to puppetise this -- need some sort of check whether this command has been run already

  file { '/etc/icinga-web/conf.d/databases.xml':
    ensure  => present,
    content => template("$module_name/icinga_web/databases.xml.erb"),
    notify  => Exec['clear web cache']
  }
  file { '/etc/icinga-web/conf.d/access.xml':
    ensure  => present,
    content => template("$module_name/icinga_web/access.xml.erb"),
    notify  => Exec['clear web cache']
  }

  exec { 'clear web cache':
    command     => '/usr/bin/icinga-web-clearcache',
    refreshonly => true,
  }

  class { 'apache':
    mpm_module => 'prefork',
  }
  class { 'apache::mod::ssl': }
  class { 'apache::mod::php': }

  apache::vhost { "${webserver_url}-http":
    servername => "${webserver_url}",
    port       => '80',
    docroot    => '/var/www',
    rewrites   => [
      {
        comment      => 'redirect http to https',
        rewrite_cond => ['%{HTTPS} off'],
        rewrite_rule => ['(.*) https://%{HTTP_HOST}%{REQUEST_URI}'],
      },
    ],
  }
  apache::vhost { "${webserver_url}-https":
    servername => "${webserver_url}",
    port       => '443',
    docroot    => "${webserver_root}",
    ssl        => true,
    rewrites   => [
      {
        comment      => 'redirect ../$ to /icinga-web/',
        rewrite_cond => ['%{REQUEST_URI} /'],
        rewrite_rule => ['^/$ /icinga-web/ [L,R=301]'],
      },
    ],
    custom_fragment => template("${module_name}/icinga_web/icinga-web.conf.erb"),
  }
}
