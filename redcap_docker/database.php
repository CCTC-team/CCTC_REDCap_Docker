<?php

global $log_all_errors;
$log_all_errors = FALSE;

$hostname   = 'db';
$db         = 'redcap';
$username   = 'root';
$password   = 'root';

$db_ssl_key     = '';
$db_ssl_cert    = '';
$db_ssl_ca      = '';
$db_ssl_capath  = NULL;
$db_ssl_cipher  = NULL;
$db_ssl_verify_server_cert = false;

$salt = '12345678';
