-- ============================================================================
-- ESI Journal — DRAFT content seed (English only, placeholders)
-- Target: journal_id = 1 (path "tj"). Test submissions/issues untouched.
-- Safe to re-run: settings upsert, announcements insert only when absent.
--
-- HOW TO APPLY (from repo root, PowerShell):
--   Get-Content seeds/seed-journal-drafts.sql | docker compose exec -T db mariadb -u pkp -psidali567 pkp
-- ROLLBACK:
--   restore backups/pre-seed-backup.sql
--
-- TODO (real content): description, ISSNs, publisher, contact, guidelines,
--   review policy, announcement text, additionalHomeContent, fr/ar locales.
-- ============================================================================

-- 1. Journal description (replaces "Short description for the Testing Journal")
-- NOTE: raw UTF-8 characters (É, —), never HTML entities — templates escape output.
UPDATE journal_settings
SET setting_value = '<p>The <strong>ESI Journal</strong> is a peer-reviewed, open access journal published by the École nationale Supérieure d''Informatique (ESI), Algiers. <strong>[DRAFT text — replace with the final mission and scope.]</strong> It welcomes original research in computer science, software engineering, artificial intelligence, data science, and information systems.</p>'
WHERE journal_id = 1 AND locale = 'en' AND setting_name = 'description';

-- 2. Placeholder ISSN (visible as "e-ISSN XXXX-XXXX" until the real one arrives)
INSERT INTO journal_settings (journal_id, locale, setting_name, setting_value)
VALUES (1, '', 'onlineIssn', 'XXXX-XXXX')
ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value);

-- 3. Publisher (drives hero meta + footer "Published by")
INSERT INTO journal_settings (journal_id, locale, setting_name, setting_value)
VALUES (1, '', 'publisherInstitution', 'École nationale Supérieure d''Informatique (ESI), Algiers')
ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value);

-- 4. Review policy draft (About > Peer Review section)
INSERT INTO journal_settings (journal_id, locale, setting_name, setting_value)
VALUES (1, 'en', 'reviewPolicy', '<p>All submissions first undergo editorial screening for scope and originality, followed by <strong>double-anonymous peer review</strong> by at least two independent reviewers. <strong>[DRAFT text — replace with the final review policy.]</strong></p>')
ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value);

-- 5. Additional homepage content (aims / indexing / calls block)
INSERT INTO journal_settings (journal_id, locale, setting_name, setting_value)
VALUES (1, 'en', 'additionalHomeContent', '<h2>Aims &amp; Scope <em>[DRAFT]</em></h2><p>The ESI Journal publishes original, high-quality research across computer science and its applications. Submissions are open year-round and all published articles are freely available under open access. <strong>[DRAFT text — replace with final aims, indexing information, and calls.]</strong></p>')
ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value);

-- 5b. Enable announcements + show them on the homepage
INSERT INTO journal_settings (journal_id, locale, setting_name, setting_value)
VALUES (1, '', 'enableAnnouncements', '1')
ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value);

-- 6. Show announcements on the homepage (default count)
INSERT INTO journal_settings (journal_id, locale, setting_name, setting_value)
VALUES (1, '', 'numAnnouncementsHomepage', '4')
ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value);

-- 7. Announcement type + welcome announcement (English draft, only if none exist)
INSERT INTO announcement_types (context_id)
SELECT 1 FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM announcement_types WHERE context_id = 1);
SET @draft_type_id = (SELECT type_id FROM announcement_types WHERE context_id = 1 LIMIT 1);
INSERT INTO announcement_type_settings (type_id, locale, setting_name, setting_value, setting_type)
SELECT @draft_type_id, 'en', 'name', 'General', 'string' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM announcement_type_settings WHERE type_id = @draft_type_id AND locale = 'en' AND setting_name = 'name');

INSERT INTO announcements (assoc_type, assoc_id, type_id, date_expire, date_posted)
SELECT 256, 1, @draft_type_id, NULL, NOW() FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM announcements WHERE assoc_type = 256 AND assoc_id = 1);
SET @draft_announcement_id = (SELECT announcement_id FROM announcements WHERE assoc_type = 256 AND assoc_id = 1 ORDER BY announcement_id DESC LIMIT 1);
INSERT INTO announcement_settings (announcement_id, locale, setting_name, setting_value)
SELECT @draft_announcement_id, 'en', 'title', 'Welcome to the new ESI Journal website [DRAFT]' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM announcement_settings WHERE announcement_id = @draft_announcement_id AND locale = 'en' AND setting_name = 'title');
INSERT INTO announcement_settings (announcement_id, locale, setting_name, setting_value)
SELECT @draft_announcement_id, 'en', 'description', '<p>The ESI Journal has launched its new publishing platform. Submissions are open year-round and all published content is freely available. <strong>[DRAFT text — replace with the final announcement.]</strong></p>' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM announcement_settings WHERE announcement_id = @draft_announcement_id AND locale = 'en' AND setting_name = 'description');
