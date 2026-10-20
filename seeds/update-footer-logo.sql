-- Point the footer logo at the generated white version (see seeds/make-white-logo.php).
UPDATE journal_settings
SET setting_value = '<img src="/public/journals/1/esi_footer_white.png" alt="ESI" width="120" />'
WHERE journal_id = 1 AND setting_name = 'pageFooter';
