# JABBER
# Nickname of user
$cfg{name}        = 'PodBot';
# Display name for Jabber in MUC
$cfg{alias}       = '>';
# Username of bot's account on the server
$cfg{username}    = 'jxtg';
# Password for this username
$cfg{password}    = 'password';
# Server IP
$cfg{server}      = 'zhmylove.ru';
# Server port
$cfg{port}        = 5222;
# Conference server address
$cfg{conference_server} = 'conference.jabber.ru';
# Rooms to join
$cfg{room_passwords} = { 'ubuntulinux' => 'ubuntu' };

# TELEGRAM
# Token
$cfg{token}       = 'token';
# Username
$cfg{tg_name}     = '@korg_jxtg_bot';
# The only chat_id to work with
$cfg{tg_chat_id}  = 1;

# MISC
# Time in uSeconds to wait between queue run (0.5 sec by default)
$cfg{sleep_usec}  = 500000;
# Max image size to transfer from Telegram to Jabber
$cfg{max_img_size}= 10485760;
