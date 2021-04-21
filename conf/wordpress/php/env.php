<?php
if ( 'cli' !== php_sapi_name() ) {
	define( 'WP_DEBUG_DISPLAY', false );
	define( 'SAVEQUERIES', true );
}

define( 'DISALLOW_FILE_EDIT', true );
define( 'DISALLOW_FILE_MODS', true );
define( 'AUTOMATIC_UPDATER_DISABLED', true );

define( 'WPCOM_IS_VIP_ENV', false );
define( 'WP_ENVIRONMENT_TYPE', 'local' );
define( 'VIP_GO_APP_ENVIRONMENT', 'local' );
define( 'VIP_BLOCK_WP_MAIL', true );
define( 'FILES_CLIENT_SITE_ID', 1 );

define( 'VIP_VAULTPRESS_SKIP_LOAD', true );
define( 'VIP_JETPACK_CONNECTION_PILOT_SHOULD_RUN', false );

/*
$all_smtp_servers = array (
	0 => 'mailcatcher:1025',
);
*/

$memcached_servers = array (
	'default' =>
	array (
		0 => 'memcached:11211',
	),
);

ini_set( 'session.save_handler', 'memcache' );
ini_set( 'session.save_path', 'tcp://memcached:11211?persistent=1' );
ini_set( 'memcache.session_redundancy', 1 );

// site pecific config overrides
if ( file_exists( '/var/www/vip-config/vip-config.php' ) ) {
	require_once( '/var/www/vip-config/vip-config.php' );
}
