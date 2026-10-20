UPDATE journal_settings
SET setting_value = '{"name":"journalThumbnailDraft_en.png","uploadName":"journalThumbnailDraft_en.png","width":600,"height":800,"dateUploaded":"2026-10-09 20:00:00"}'
WHERE journal_id = 1 AND locale = 'en' AND setting_name = 'journalThumbnail';
