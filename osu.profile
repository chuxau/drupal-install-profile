<?php
/**
 Copyright (C) 2013 Oregon State University

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program. If not, see http://www.gnu.org/licenses/.

 To contact us, go to http://oregonstate.edu/cws/contact and fill out the contact form.

 Alternatively mail us at:

 Oregon State University
 Central Web Services
 121 The Valley Library
 Corvallis, OR 97331
*/

/**
 * @file
 * Enables modules and site configuration for OSU Drupal
 */

/**
 * Implements hook_install_tasks().
 *
 */
function osu_install_tasks($install_state) {
  $tasks = array(
    'osu_configure' => array(
      'display_name' => st('OSU Drupal Configuration'),
      'function' => 'osu_configure',
    ),
    'osu_config_permissions' => array(
      'display_name' => st('Configure Site Permissions'),
      'function'     => 'osu_config_permissions',
    ),
    'osu_default_content' => array(
      'display_name' => st('OSU default content'),
      'function' => 'osu_default_content',
    ),
  );
  return $tasks;
}


/**
 * Implements hook_install_tasks_alter()
 *
 */
function osu_install_tasks_alter(&$tasks, $install_state) {

  // Since we only offer one language, define a callback to set this
  $tasks['install_select_locale']['function'] = 'osu_locale_selection';

    // Create a more fun finished page with our Open Academy Saurus
  $tasks['install_finished']['function'] = 'OSU_finished';
  $tasks['install_finished']['display_name'] = t('Finished!');
  $tasks['install_finished']['type'] = 'form';
}

/**
 * Task handler to set the language to English
 *
 */
function osu_locale_selection(&$install_state) {
  $install_state['parameters']['locale'] = 'en';
}


/**
 * Implementation of hook_form_FORM_ID_alter().
 * This sets some defaults for the installer
 *
 */
function osu_form_install_configure_form_alter(&$form, $form_state) {
  // Set default for site name field.
  $form['site_information']['site_name']['#default_value'] = 'OSU Drupal';
  $form['site_information']['site_mail']['#default_value'] = 'cws-noreply@oregonstate.edu';
  $form['admin_account']['account']['name']['#default_value'] = 'cws_dpla';
  $form['admin_account']['account']['mail']['#default_value'] = 'cws-noreply@oregonstate.edu';
  $form['admin_account']['account']['pass']['pass1']['#default_value'] = 'not_null';

  // Timnezone settings.
  $form['server_settings']['site_default_country']['#default_value'] = 'US';
  $form['server_settings']['date_default_timezone']['#default_value'] = 'America/Los Angeles';

  // Update notifications.
  $form['update_notifications']['update_status_module']['#default_value'] = array();

  // Disable validate.
  $form['#validate'] = array();

}

/**
 * Implements hook_form_alter().
 * Set OSU as the default profile.
 * (copied from Atrium: We use system_form_form_id_alter, otherwise we cannot alter forms.)
 */
function system_form_install_select_profile_form_alter(&$form, $form_state) {
  foreach ($form['profile'] as $key => $element) {
    $form['profile'][$key]['#value'] = 'osu';
  }
}

/**
 * Custom OSU functions start here
 */

/**
 * Final configuration tasks
 *
 */
function osu_configure() {

  osu_config_misc();
  osu_config_pathauto();
  osu_config_blocks();
  osu_config_filters();

  // Clear the cache
  drupal_flush_all_caches();
}

/**
 * Misc. configuration settings
 * Set of lot if variables
 */
function osu_config_misc() {
  $osu_default_theme = 'osu_standard';
  $osu_admin_theme   = 'seven';

  theme_enable(array($osu_default_theme, $osu_admin_theme));

  // Set Default theme
  variable_set('theme_default', $osu_default_theme);

  // Enable the admin theme.
  variable_set('admin_theme', $osu_admin_theme);
  variable_set('node_admin_theme', '1');

  // Configure admin menu
  variable_set('admin_menu_position_fixed', 1);
  variable_set('admin_menu_margin_top', 1);

  // Misc stuff to sort into functions later
  variable_set('site_frontpage','node/1');

  // Clean URLs
  variable_set('clean_url', 1);

  //prevent public user registration
  variable_set('user_register', '0');

  //vars for file
  variable_set('file_directory_path', 'sites/default/files');
  variable_set('file_directory_temp', '/tmp');

  // Timezone
  variable_set('date_default_timezone', 'America/Los_Angeles');
  variable_set('configurable_timezones', 0);
  variable_set('user_default_timezone', 0);
  variable_set('empty_timezone_message', 0);
  variable_set('date_first_day', '0');

  // Do not display author username and publish date on our content types
  variable_set('node_submitted_feature_story', 0);
  variable_set('node_submitted_video', 0);
  variable_set('node_submitted_page', 0);

 // Set the new user welcome message
  $new_user_message = <<<EOL
[user:name],
Your account on [site:name] has created!

Log in at [site:login-url]
EOL;

  variable_set('user_mail_register_admin_created_body', $new_user_message);

  // Set CAS user for cws_dpla
  $query = db_insert('cas_user')->fields(array('uid', 'cas_name'));
  $query->values(array(1, 'cws_dpla'));
  $query->execute();

}


/** Clean up some blocks enabled by the standard install
 *
 */
function osu_config_blocks() {
  db_update('block')
    ->fields(array('status' => 0, 'region' => -1 ))
    ->condition('module', 'system')
    ->condition('delta', 'powered-by')
    ->execute();

  db_update('block')
    ->fields(array('status' => 0, 'region' => -1 ))
    ->condition('module', 'system')
    ->condition('delta', 'navigation')
    ->execute();

  db_update('block')
    ->fields(array('status' => 0, 'region' => -1 ))
    ->condition('module', 'search')
    ->execute();

  db_update('block')
    ->fields(array('status' => 0, 'region' => -1 ))
    ->condition('module', 'user')
    ->execute();
}

/** Enable a couple of filters for both formats
 * The formats already exist but we need to add filters for
 * media tags and internal URLS
 */
function osu_config_filters() {
  $formats = array('filtered_html', 'full_html');
  foreach ($formats as $format_name) {

    // First load the format
    $format = filter_format_load($format_name);
    if (empty($format->filters)) {
      // Get the filters used by this format.
      $filters = filter_list_format($format->format);
      // Build the $format->filters array...
      $format->filters = array();
      foreach($filters as $name => $filter) {
        foreach($filter as $k => $v) {
          $format->filters[$name][$k] = $v;
        }
      }
    }
    // Check to see if the media filter exists yet
    if (isset($format->filters['media_filter'])){
      // Filter exists so just enable it
      $format->filters['media_filter']['status'] = '1';
    }
    else {
      // Create the filter
      $format->filters['media_filter'] = array(
          'format'  => $format_name,
          'module'  => 'media',
          'name'    => 'media_filter',
          'weight'  => '2',
          'status'  => '1',
          );
    }

    // Do the same for the  pathfilter
    if (isset($format->filters['pathfilter'])){
      // Filter exists so just enable it
      $format->filters['pathfilter']['status'] = '1';
    }
    else {
      // Create the filter
      $format->filters['pathfilter'] = array(
          'format'   => $format_name,
          'module'   => 'pathfilter',
          'name'     => 'pathfilter',
          'weight'   => '0',
          'status'   => '1',
          'settings' => array(
            'link_absolute'  => '1',
            'process_all'    => '1',
          ),
        );
    }
    // Save the format
    filter_format_save($format);
  }
}

/**
 * Setup tokens for pathauto
 *
 */
function osu_config_pathauto() {
  variable_set('pathauto_blog_pattern', 'blogs/[user:name]');
  variable_set('pathauto_forum_pattern', '[term:vocabulary]/[term:name]');
  variable_set('pathauto_node_announcement_pattern', '');
  variable_set('pathauto_node_article_pattern', '');
  variable_set('pathauto_node_biblio_pattern', '');
  variable_set('pathauto_node_book_pattern', 'book/[node:title]');
  variable_set('pathauto_node_feature_story_pattern', '');
  variable_set('pathauto_node_feed_pattern', '');
  variable_set('pathauto_node_location_pattern', '');
  variable_set('pathauto_node_page_pattern', '[node:title]');
  variable_set('pathauto_node_pattern', '[node:content-type]/[node:title]');
  variable_set('pathauto_node_person_pattern', 'people/[node:title]');
  variable_set('pathauto_node_photo_album_pattern', 'photo-album/[node:title]');
  variable_set('pathauto_node_stylesheet_overlay_pattern', '');
  variable_set('pathauto_node_webform_pattern', '');
  variable_set('pathauto_punctuation_hyphen', 1);
  variable_set('pathauto_taxonomy_term_organization2_91222_pattern', '');
  variable_set('pathauto_taxonomy_term_pattern', '[term:vocabulary]/[term:name]');
  variable_set('pathauto_taxonomy_term_tags_pattern', '');
  variable_set('pathauto_user_pattern', 'users/[user:name]');
  drupal_set_message(t('Configured the Pathauto module'));
}

/**
 * Create some default content
 *
 */
function osu_default_content() {
  osu_config_pages();
  osu_config_menus();
  osu_config_feeds();
  osu_import_media();
  osu_config_feature_story();
}


/**
 * Create the default feeds
 *
 */
function osu_config_feeds() {
 // Define the feeds
  $feeds = array(
    'news' => array(
      'feed_title'      => st('OSU News'),
      'feed_url'        => t('http://oregonstate.edu/ua/ncs/releases/feed'),
      'num_items'       => 4,
      'feed_type'       => 'osu_news',
    ),
    'events' => array(
      'feed_title'      => st('OSU Events'),
      'feed_url'        => t('http://calendar.oregonstate.edu/today+60/list/osu/rss20.xml'),
      'num_items'       => 5,
      'feed_type'       => 'osu_events',
    ),
  );

  // Create the nodes
  foreach ($feeds as $name => $feed) {
    $node = new stdClass;
    $node->name         = $name;
    $node->title        = $feed['feed_title'];
    $node->feed_title   = $feed['feed_title'];
    $node->feed_url     = $feed['feed_url'];
    $node->num_items    = $feed['num_items'];
    $node->feed_type    = $feed['feed_type'];
    $node->type         = 'feed';
    $node->language     = 'en';
    $node->created      = strtotime("now");
    $node->changed      = $node->created;
    $node->enable_block = $name == 'news' ? 'main_first' : 'main_second';
    node_save($node);
  }

  drupal_set_message(t('The default feeds have been created.'));
}


/**
 * Build first 3 nodes
 *
 *  Home
 *  About
 *  Login
 *
 */
function osu_config_pages() {

  // Home
  $body  = '<h3>Welcome to your new Drupal site</h3>';
  $body .= '<p>This is your front page, <strong>do not</strong> delete it.';
  $body .= 'You can edit this page, remove this content, and add your own.';
  $body .= '<p>To learn more about building your site, visit our <a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6">Drupal Training Materials</a>.</p>';
  $body .= '<p><a href="./login">Log in</a> to your new site to change this page and start adding your own content.</p>';

  $node = new stdClass();

  //Main Node Fields
  $node->name     = 'Home';
  $node->title    = $node->name;
  $node->type     = 'page'; //This can be any node type
  $node->created  = strtotime('now');
  $node->changed  = $node->created;
  $node->promote  = 0; // Display on front page ? 1 : 0
  $node->sticky   = 0; // Display top of page ? 1 : 0
  $node->status   = 1; // Published ? 1 : 0
  $node->language = 'en';

  $node->body['und'][0]['format'] = 'full_html';
  $node->body['und'][0]['value']  = $body;

  node_save($node);

  // Drupal7 creates the alias to this new node as content/home
  // We want to change it to just home
  $res = db_update('url_alias')
    ->fields(array('alias' => 'home'))
    ->condition('alias', 'content/home')
    ->execute();


 // About
  $body  = '<h3>About Us</h3>';
  $body .= '<p>This is your about page.</p>';
  $body .= '<p>You can edit this page, remove this content, and add your own.</p>';

  $node = new stdClass();
  $node->name     = 'About';
  $node->title    = $node->name;
  $node->type     = 'page'; //This can be any node type
  $node->created  = strtotime('now');
  $node->changed  = $node->created;
  $node->promote  = 0; // Display on front page ? 1 : 0
  $node->sticky   = 0; // Display top of page ? 1 : 0
  $node->status   = 1; // Published ? 1 : 0
  $node->language = 'en';

  $node->body['und'][0]['format'] = 'full_html';
  $node->body['und'][0]['value']  = $body;

  node_save($node);

  $res = db_update('url_alias')
    ->fields(array('alias' => 'about'))
    ->condition('alias', 'content/about')
    ->execute();


 // Login
  $body  = '<h3>You are now logged in to the site</h3>';
  $body .= '<p>This is your login page. ';
  $body .= 'Accessing this page will cause people to be redirected to the OSU login page.';
  $body .= 'This is a good place to put instructions for your site authors or anyone else who will be logging in to the site.</p>';
  $body .= '<p>You can edit this page, remove this content, and add your own.</p>';

  $node = new stdClass();

  //Main Node Fields
  $node->name     = 'Login';
  $node->title    = $node->name;
  $node->type     = 'page'; //This can be any node type
  $node->created  = strtotime('now');
  $node->changed  = $node->created;
  $node->promote  = 0; // Display on front page ? 1 : 0
  $node->sticky   = 0; // Display top of page ? 1 : 0
  $node->status   = 1; // Published ? 1 : 0
  $node->language = 'en';

  $node->body['und'][0]['format'] = 'full_html';
  $node->body['und'][0]['value']  = $body;

  node_save($node);

  // Drupal7 creates the alias to this new node as content/login
  // We want to change it to just login
  $res = db_update('url_alias')
    ->fields(array('alias' => 'login'))
    ->condition('alias', 'content/login')
    ->execute();

  // A custom block for help links
  $block = new stdClass();
  $block->info   = 'Drupal Help Block';
  $block->format = 'full_html';
  $block->body =<<<EOL
<ul>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/login">Login</a></li>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/announcements">Announcements</a></li>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/basic-content-types">Basic Content Types</a></li>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/bibliography">Bibliography</a></li>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/blocks">Blocks</a></li>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/books">Books</a></li>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/cck">CCK</a></li>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/content-access">Content Access</a></li>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/features">Features</a></li>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/feeds-display">Feeds Display</a></li>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/gallerix">Gallerix</a></li>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/glossary">Glossary</a></li>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/imce-file-browser">IMCE File Browser</a></li>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/imagecache">ImageCache</a></li>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/menus">Menus</a></li>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/poll">Poll</a></li>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/taxonomy">Taxonomy</a></li>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/themes">Themes</a></li>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/tinymce-wysiwyg-text-editor">TinyMCE / WYSIWYG Text Editor</a></li>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/token">Token</a></li>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/views">Views</a></li>
<li><a href="http://oregonstate.edu/cws/training/book/drupal-deep-dive/osu-drupal-6/webform">Webform</a></li>
</ul>
EOL;

  drupal_write_record('block_custom', $block);

  // Add the custom block to the block table
  db_insert('block')
    ->fields(array('module'     => 'block',
                   'delta'      => 1,
                   'theme'      => 'osu_standard',
                   'status'     => 1,
                   'weight'     => 10,
                   'region'     => 'sidebar_first',
                   'custom'     => 0,
                   'visibility' => 0,
                   'pages'      => '',
                   'cache'      => -1,
                   'title'      => 'Drupal Help'))
    ->execute();

  // Limit block visibility by roles.
  // We have to assume 3, 4, and 5 are our custome roles
  // and the custom_block_id is 1
  $roles = array(3, 4, 5, 6);
  foreach ($roles as $role) {
    db_insert('block_role')
        ->fields( array('module' => 'block',
                        'delta'  => 1,
                        'rid'    => $role))
        ->execute();
  }

  drupal_set_message(t('The default pages have been created.'));
}



/**
 * Create a Feature Story
 *
 */
function osu_config_feature_story() {

  // Feature story should be enabled so lets create one
  $node = new stdClass();
  $node->type     = 'feature_story';
  $node->title    = 'Sample Feature Story';
  $node->status   = 1;
  $node->promote  = 1;
  $node->created  = strtotime('now');
  $node->changed  = $node->created;
  $node->language = 'en';

  // Add the body
  $node->body['und'][0]['value']  = 'Replace this with your own feature story content';
  $node->body['und'][0]['format'] = 'filtered_html';

  // Add the picture
  $node->field_picture['und'][0]['fid']    = 1;
  $node->field_picture['und'][0]['width']  = 1000;
  $node->field_picture['und'][0]['height'] = 667;
  $node->field_picture['und'][0]['title']  = $node->title;
  $node->field_picture['und'][0]['alt']    = 'Sample Feature Story Picture';

  // Add the caption
  $node->field_caption['und'][0]['value']  = 'Replace this with your own feature story content';
  $node->field_caption['und'][0]['format'] =  'plain_text';

  // Toggle show on front page
  $node->field_feature_story_front['und'][0]['value'] = 1;

  node_save($node);

  // Add the views block to the features region
  $block = array(
    'status'      => 1,
    'weight'      => 0,
    'region'      => 'features',
    'visibility'  => 1,
    'pages'       => '<front>',
    'cache'       => -1,
    'title'       => '<none>',
  );

  db_update('block')
    ->fields($block)
    ->condition('module', 'views')
    ->condition('theme', 'osu_standard')
    ->condition('delta', 'feature_story-block')
    ->execute();

}


/**
 * Import existing media for feature-story
 *
 */
function osu_import_media() {
  // Let's try and import some media

  // Not sure if I should be using module_load_include() here instead
  require_once(drupal_get_path('module', 'media') . '/includes/media.admin.inc');

  // $dir = 'sites/default/files/feature-story';
  $dir = drupal_get_path('module', 'feature_story') .  '/images';
  $ext = '*.jpg';
  $files = glob("$dir/$ext");

  $image_in_message = FALSE;

  // This code is copied directly from media.admin.inc
  foreach ($files as $file) {
    try {
      $file_obj = media_parse_to_file($file);
      $context['results']['success'][] = $file;
      if (!$image_in_message) {
        // @todo Is this load step really necessary? When there's time, test
        //   this, and either remove it, or comment why it's needed.
        $loaded_file = file_load($file_obj->fid);
        $image_in_message = file_view_file($loaded_file, 'media_preview');
      }
    }
    catch (Exception $e) {
      $context['results']['errors'][] = $file . " Reason: " . $e->getMessage();
    }
  }

  drupal_set_message(t('The media has been imported.'));
}


/**
 * Configure Main menu and Audience menu
 *
 */
function osu_config_menus() {
   // Create a Home link in the main menu.
   /* seems like Home is already there at this point
  $item = array(
    'link_title' => st('Home'),
    'link_path'  => '<front>',
    'menu_name'  => 'main-menu',
    'weight'     => -10,
  );
  menu_link_save($item);
  */

  // Create a About link in the main menu.
  $item = array(
    'link_title' => st('About'),
    'link_path'  => drupal_get_normal_path('about'),
    'menu_name'  => 'main-menu',
    'weight'     => 1,
  );
  menu_link_save($item);

  // Update the menu router information.
  menu_cache_clear_all();

  // Create a default audience menu
  $targets = array(
    'Future Students',
    'Current Students',
    'Alumni & Parents',
    'Faculty & Staff',
  );

  // Create the menu
  $menu = array(
    'menu_name'   => 'audience-menu',
    'title'       => t('Audience Menu'),
    'description' => t('The audience menu'),
  );
  menu_save($menu);

  // Add the links
  foreach ($targets as $weight => $target) {
    $item = array(
      'link_title' => st($target),
      'link_path'  => 'node/2',
      'menu_name'  => 'audience-menu',
      'weight'     => $weight,
    );
    menu_link_save($item);
  }
  menu_cache_clear_all();

  // Now put the menu in the primary sidebar
  $block = array(
    'module'      => 'menu',
    'delta'       => 'audience-menu',
    'theme'       => 'osu_standard',
    'status'      => 1,
    'weight'      => 0,
    'region'      => 'sidebar_first',
    'pages'       => '',
    'cache'       => -1,
    'title'       => '<none>',
  );
  $query = db_insert('block')
      ->fields($block)
      ->execute();

  // Configure a nice menu for the main menu
	variable_set('nice_menus_js',       1);
	variable_set('nice_menus_number',   '2');
	variable_set('nice_menus_sf_delay', '800');
	variable_set('nice_menus_sf_speed', 'slow');
  variable_set('nice_menus_menu_1',   'main-menu');
	variable_set('nice_menus_name_1',   'Nice menu 1 (Main Menu)');
	variable_set('nice_menus_type_1',   'down');
	variable_set('nice_menus_depth_1',  '-1');

  // Add the nice menu block to the nav region
  db_update('block')
      ->fields(array(
        'region' => 'nav',
        'status' => 1,
        'title'  => '<none>'
        )
      )
      ->condition('theme', 'osu_standard')
      ->condition('module', 'nice_menus')
      ->condition('delta', 1)
      ->execute();

  drupal_set_message(t('The default menus have been created.'));
}


/**
 * Form to finish it all out and send us on our way
 */
function osu_finished($form, &$form_state) {
  $form = array();

  $form['opening'] = array(
    '#markup' => '<h1>' . t('Finished!') . '</h1>',
  );

  $form['openingtext'] = array(
    '#markup' => '<h2>' . t('Congratulations, you just installed OSU Drupal!') . '</h2>',
  );


  $form['submit'] = array(
    '#type' => 'submit',
    '#value' => 'Visit your new site!',
  );

  return $form;
}

/**
 * Submit form to finish it out and send us on our way!
 */
function osu_finished_submit($form, &$form_state) {

  // Allow anonymous and authenticated users to see content
  user_role_grant_permissions(DRUPAL_ANONYMOUS_RID, array('access content'));
  user_role_grant_permissions(DRUPAL_AUTHENTICATED_RID, array('access content'));

  // Once more for good measure
  drupal_flush_all_caches();

  // And away we go
  // $form_state['redirect'] won't work here since we are still in the
  // installer, so use drupal_goto() (for interactive installs only) instead.
  $install_state = $form_state['build_info']['args'][0];
  if ($install_state['interactive']) {
    drupal_goto('<front>');
  }
}


/**
 * Configure permissions
 * This needs to be done near the end so that all of these permissions are
 * already defined.
 *
 */
function osu_config_permissions() {
  $permissions = array(
    // Anonymous
    '1' => array(
      'access biblio content' => '1',
      'access content'        => '1',
      'search content'        => '1',
      'show filter tab'       => '1',
      'show sort links'       => '1',
      'use advanced search'   => '1',
      'view full text'        => '1',
      'view media'    => '1',
    ),
    // Authenticated
    '2' => array(
      'access biblio content' => '1',
      'access content'        => '1',
      'access own webform results'    => '1',
      'access own webform submissions'        => '1',
      'access user profiles'  => '1',
      'search content'        => '1',
      'show filter tab'       => '1',
      'show sort links'       => '1',
      'use advanced search'   => '1',
      'view full text'        => '1',
      'view media'    => '1',
    ),
    // Manager
    '3' => array(
      'access administration menu'    => '1',
      'access administration pages'   => '1',
      'access all webform results'    => '1',
      'access content overview'       => '1',
      'access contextual links'       => '1',
      'access dashboard'      => '1',
      'access overlay'        => '1',
      'access own webform results'    => '1',
      'access site reports'   => '1',
      'add media from remote sources' => '1',
      'administer actions'    => '1',
      'administer biblio'     => '1',
      'administer blocks'     => '1',
      'administer CAPTCHA settings'   => '1',
      'administer cas'        => '1',
      'administer content types'      => '1',
      'administer date tools' => '1',
      'administer features'   => '1',
      'administer filters'    => '1',
      'administer image styles'       => '1',
      'administer imce'       => '1',
      'administer lightbox2'  => '1',
      'administer media'      => '1',
      'administer menu'       => '1',
      'administer pathauto'   => '1',
      'administer permissions'        => '1',
      'administer quicktabs'  => '1',
      'administer recaptcha'  => '1',
      'administer search'     => '1',
      'administer shortcuts'  => '1',
      'administer site configuration' => '1',
      'administer taxonomy'   => '1',
      'administer themes'     => '1',
      'administer url aliases'        => '1',
      'administer users'      => '1',
      'administer views'      => '1',
      'configure search'      => '1',
      'configure top hat'     => '1',
      'create article content'        => '1',
      'create biblio content' => '1',
      'create feed'   => '1',
      'create feed content'   => '1',
      'create page content'   => '1',
      'create url aliases'    => '1',
      'create webform content'        => '1',
      'customize shortcut links'      => '1',
      'delete all webform submissions'        => '1',
      'delete any article content'    => '1',
      'delete any biblio content'     => '1',
      'delete any feed content'       => '1',
      'delete any page content'       => '1',
      'delete any webform content'    => '1',
      'delete own article content'    => '1',
      'delete own biblio content'     => '1',
      'delete own feed content'       => '1',
      'delete own page content'       => '1',
      'delete own webform content'    => '1',
      'delete own webform submissions'        => '1',
      'delete revisions'      => '1',
      'delete terms in 1'     => '1',
      'download original image'       => '1',
      'edit all webform submissions'  => '1',
      'edit any article content'      => '1',
      'edit any biblio content'       => '1',
      'edit any feed content' => '1',
      'edit any page content' => '1',
      'edit any webform content'      => '1',
      'edit biblio authors'   => '1',
      'edit by all biblio authors'    => '1',
      'edit feed'     => '1',
      'edit media'    => '1',
      'edit own article content'      => '1',
      'edit own biblio content'       => '1',
      'edit own feed content' => '1',
      'edit own page content' => '1',
      'edit own webform content'      => '1',
      'edit own webform submissions'  => '1',
      'edit terms in 1'       => '1',
      'flush caches'  => '1',
      'import from file'      => '1',
      'import media'  => '1',
      'manage features'                   => '1',
      'revert revisions'                  => '1',
      'show download links'               => '1',
      'show export links'                 => '1',
      'show own download links'           => '1',
      'skip CAPTCHA'                      => '1',
      'switch shortcut sets'              => '1',
      'use text format filtered_html'     => '1',
      'use text format full_html'         => '1',
      'view advanced help index'          => '1',
      'view advanced help popup'          => '1',
      'view advanced help topic'          => '1',
      'view own unpublished content'      => '1',
      'view revisions'                    => '1',
      'view the administration theme'     => '1',
    ),
    // Architect
    '4' => array(
      'access administration menu'        => '1',
      'access administration pages'       => '1',
      'access content overview'           => '1',
      'access contextual links'           => '1',
      'access dashboard'                  => '1',
      'access overlay'                    => '1',
      'access own webform results'        => '1',
      'add media from remote sources'     => '1',
      'administer biblio'                 => '1',
      'administer blocks'                 => '1',
      'administer CAPTCHA settings'       => '1',
      'administer content types'          => '1',
      'administer date tools'             => '1',
      'administer features'               => '1',
      'administer filters'                => '1',
      'administer image styles'           => '1',
      'administer imce'                   => '1',
      'administer lightbox2'              => '1',
      'administer media'                  => '1',
      'administer menu'                   => '1',
      'administer pathauto'               => '1',
      'administer quicktabs'              => '1',
      'administer recaptcha'              => '1',
      'administer search'                 => '1',
      'administer shortcuts'              => '1',
      'administer taxonomy'               => '1',
      'administer themes'                 => '1',
      'administer url aliases'            => '1',
      'administer views'                  => '1',
      'configure search'                  => '1',
      'configure top hat'                 => '1',
      'create article content'            => '1',
      'create biblio content'             => '1',
      'create feed'                       => '1',
      'create feed content'               => '1',
      'create page content'               => '1',
      'create url aliases'                => '1',
      'create webform content'            => '1',
      'customize shortcut links'          => '1',
      'delete any article content'        => '1',
      'delete any biblio content'         => '1',
      'delete any feed content'           => '1',
      'delete any page content'           => '1',
      'delete any webform content'        => '1',
      'delete own article content'        => '1',
      'delete own biblio content'         => '1',
      'delete own feed content'           => '1',
      'delete own page content'           => '1',
      'delete own webform content'        => '1',
      'delete revisions'                  => '1',
      'delete terms in 1'                 => '1',
      'download original image'           => '1',
      'edit any article content'          => '1',
      'edit any biblio content'           => '1',
      'edit any feed content'             => '1',
      'edit any page content'             => '1',
      'edit any webform content'          => '1',
      'edit biblio authors'               => '1',
      'edit by all biblio authors'        => '1',
      'edit feed'                         => '1',
      'edit media'                        => '1',
      'edit own article content'          => '1',
      'edit own biblio content'           => '1',
      'edit own feed content'             => '1',
      'edit own page content'             => '1',
      'edit own webform content'          => '1',
      'edit terms in 1'                   => '1',
      'flush caches'                      => '1',
      'import from file'                  => '1',
      'import media'                      => '1',
      'manage features'                   => '1',
      'revert revisions'                  => '1',
      'show download links'               => '1',
      'show export links'                 => '1',
      'show own download links'           => '1',
      'skip CAPTCHA'                      => '1',
      'switch shortcut sets'              => '1',
      'use text format filtered_html'     => '1',
      'use text format full_html'         => '1',
      'view advanced help index'          => '1',
      'view advanced help popup'          => '1',
      'view advanced help topic'          => '1',
      'view own unpublished content'      => '1',
      'view revisions'                    => '1',
      'view the administration theme'     => '1',
    ),
    // Author
    '5' => array(
      'access administration menu'    => '1',
      'access administration pages'   => '1',
      'access content overview'       => '1',
      'access contextual links'       => '1',
      'access dashboard'      => '1',
      'access overlay'        => '1',
      'access own webform results'    => '1',
      'add media from remote sources' => '1',
      'administer media'      => '1',
      'create article content'        => '1',
      'create biblio content' => '1',
      'create feed'   => '1',
      'create feed content'   => '1',
      'create page content'   => '1',
      'create url aliases'    => '1',
      'create webform content'        => '1',
      'delete any article content'    => '1',
      'delete any biblio content'     => '1',
      'delete any feed content'       => '1',
      'delete any page content'       => '1',
      'delete any webform content'    => '1',
      'delete own article content'    => '1',
      'delete own biblio content'     => '1',
      'delete own feed content'       => '1',
      'delete own page content'       => '1',
      'delete own webform content'    => '1',
      'delete revisions'      => '1',
      'delete terms in 1'     => '1',
      'download original image'       => '1',
      'edit any article content'      => '1',
      'edit any biblio content'       => '1',
      'edit any feed content' => '1',
      'edit any page content' => '1',
      'edit any webform content'      => '1',
      'edit feed'     => '1',
      'edit media'    => '1',
      'edit own article content'      => '1',
      'edit own biblio content'       => '1',
      'edit own feed content' => '1',
      'edit own page content' => '1',
      'edit own webform content'      => '1',
      'edit terms in 1'       => '1',
      'flush caches'  => '1',
      'import media'  => '1',
      'revert revisions'      => '1',
      'skip CAPTCHA'  => '1',
      'use text format filtered_html' => '1',
      'use text format full_html'     => '1',
      'view advanced help index'      => '1',
      'view advanced help popup'      => '1',
      'view advanced help topic'      => '1',
      'view revisions'        => '1',
      'view the administration theme' => '1',
    ),
  );

  foreach ($permissions as $rid => $perms) {
    user_role_change_permissions($rid, $perms);
  }
}



