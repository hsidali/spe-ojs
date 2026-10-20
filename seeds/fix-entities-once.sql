-- One-off fix: replace HTML entities with raw UTF-8 in rows inserted
-- by the first (buggy) seed run. The seed file itself is already fixed,
-- so this file is only needed once and kept for the record.
UPDATE announcement_settings
SET setting_value = '<p>The ESI Journal has launched its new publishing platform. Submissions are open year-round and all published content is freely available. <strong>[DRAFT text — replace with the final announcement.]</strong></p>'
WHERE announcement_id = 1 AND locale = 'en' AND setting_name = 'description';
