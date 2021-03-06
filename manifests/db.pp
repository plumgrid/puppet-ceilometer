# == Class: ceilometer::db
#
#  Configures the ceilometer database
#  This class will install the required libraries depending on the driver
#  specified in the connection_string parameter
#
# == Parameters

# [*database_connection*]
#   Url used to connect to database.
#   (Optional) Defaults to 'mysql://ceilometer:ceilometer@localhost/ceilometer'.
#
# [*database_idle_timeout*]
#   Timeout when db connections should be reaped.
#   (Optional) Defaults to 3600.
#
# [*database_min_pool_size*]
#   Minimum number of SQL connections to keep open in a pool.
#   (Optional) Defaults to 1.
#
# [*database_max_pool_size*]
#   Maximum number of SQL connections to keep open in a pool.
#   (Optional) Defaults to 10.
#
# [*database_max_retries*]
#   Maximum db connection retries during startup.
#   Setting -1 implies an infinite retry count.
#   (Optional) Defaults to 10.
#
# [*database_retry_interval*]
#   Interval between retries of opening a sql connection.
#   (Optional) Defaults to 10.
#
# [*database_max_overflow*]
#   If set, use this value for max_overflow with sqlalchemy.
#   (Optional) Defaults to 20.
#
# [*mongodb_replica_set*]
#   The name of the replica set which is used to connect to MongoDB
#   database. If it is set, MongoReplicaSetClient will be used instead
#   of MongoClient.
#   (Optional) Defaults to undef (string value).
#
#  [*sync_db*]
#    enable dbsync.
#
class ceilometer::db (
  $database_connection     = 'mysql://ceilometer:ceilometer@localhost/ceilometer',
  $database_idle_timeout   = 3600,
  $database_min_pool_size  = 1,
  $database_max_pool_size  = 10,
  $database_max_retries    = 10,
  $database_retry_interval = 10,
  $database_max_overflow   = 20,
  $sync_db                 = true,
  $mongodb_replica_set     = undef,
) {

  include ::ceilometer::params

  Package<| title == 'ceilometer-common' |> -> Class['ceilometer::db']

  validate_re($database_connection,
    '(sqlite|mysql|postgresql|mongodb):\/\/(\S+:\S+@\S+\/\S+)?')

  case $database_connection {
    /^mysql:\/\//: {
      $backend_package = false
      require 'mysql::bindings'
      require 'mysql::bindings::python'
    }
    /^postgresql:\/\//: {
      $backend_package = false
      require 'postgresql::lib::python'
    }
    /^mongodb:\/\//: {
      $backend_package = $::ceilometer::params::pymongo_package_name
      if $mongodb_replica_set {
        ceilometer_config { 'database/mongodb_replica_set':  value => $mongodb_replica_set; }
      } else {
        ceilometer_config { 'database/mongodb_replica_set':  ensure => absent; }
      }
    }
    /^sqlite:\/\//: {
      $backend_package = $::ceilometer::params::sqlite_package_name
    }
    default: {
      fail('Unsupported backend configured')
    }
  }

  if $backend_package and !defined(Package[$backend_package]) {
    package {'ceilometer-backend-package':
      ensure => present,
      name   => $backend_package,
      tag    => 'openstack',
    }
  }

  ceilometer_config {
    'database/connection':     value => $database_connection, secret => true;
    'database/idle_timeout':   value => $database_idle_timeout;
    'database/min_pool_size':  value => $database_min_pool_size;
    'database/max_retries':    value => $database_max_retries;
    'database/retry_interval': value => $database_retry_interval;
    'database/max_pool_size':  value => $database_max_pool_size;
    'database/max_overflow':   value => $database_max_overflow;
  }

  if $sync_db {
    include ::ceilometer::db::sync
  }

}
