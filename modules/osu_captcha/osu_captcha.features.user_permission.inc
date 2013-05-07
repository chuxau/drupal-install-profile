<?php
/**
 * @file
 * osu_captcha.features.user_permission.inc
 */

/**
 * Implements hook_user_default_permissions().
 */
function osu_captcha_user_default_permissions() {
  $permissions = array();

  // Exported permission: administer CAPTCHA settings
  $permissions['administer CAPTCHA settings'] = array(
    'name' => 'administer CAPTCHA settings',
    'roles' => array(
      0 => 'administrator',
    ),
    'module' => 'captcha',
  );

  // Exported permission: skip CAPTCHA
  $permissions['skip CAPTCHA'] = array(
    'name' => 'skip CAPTCHA',
    'roles' => array(
      0 => 'administrator',
      1 => 'manager',
      2 => 'architect',
      3 => 'author',
    ),
    'module' => 'captcha',
  );

  return $permissions;
}
