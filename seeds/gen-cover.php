<?php
/**
 * seeds/gen-cover.php — generate a DRAFT journal thumbnail cover.
 *
 * Navy ESI placeholder (600x800 PNG) to replace the unsuitable personal
 * photo currently used as journalThumbnail. Run inside the app container:
 *
 *   docker compose cp seeds/gen-cover.php app:/tmp/gen-cover.php
 *   docker compose exec -T app php /tmp/gen-cover.php /tmp/journalThumbnailDraft_en.png
 *   docker compose cp app:/tmp/journalThumbnailDraft_en.png volumes/public/journals/1/journalThumbnailDraft_en.png
 *
 * Then point the `journalThumbnail` (en) journal setting at the new file.
 * TODO: replace with the final designed cover.
 */
if ($argc < 2) {
    fwrite(STDERR, "Usage: php gen-cover.php <output.png>\n");
    exit(1);
}
$output = $argv[1];
$fontBold = '/usr/share/fonts/truetype/noto/NotoSansMono-Bold.ttf';
$fontRegular = '/usr/share/fonts/truetype/noto/NotoSansMono-Regular.ttf';
if (!is_file($fontBold) || !is_file($fontRegular)) {
    fwrite(STDERR, "Required fonts not found.\n");
    exit(1);
}

$W = 600; $H = 800;
$img = imagecreatetruecolor($W, $H);
$navy = imagecolorallocate($img, 11, 18, 32);
$blue = imagecolorallocate($img, 0, 96, 176);
$lightBlue = imagecolorallocate($img, 115, 191, 255);
$white = imagecolorallocate($img, 255, 255, 255);
$muted = imagecolorallocate($img, 150, 163, 175);
imagefill($img, 0, 0, $navy);

// Top accent bar
imagefilledrectangle($img, 0, 0, $W, 10, $blue);
// Thin frame
imagerectangle($img, 14, 14, $W - 15, $H - 15, $blue);

$center = function ($size, $font, $text, $y, $color) use ($img, $W) {
    $box = imagettfbbox($size, 0, $font, $text);
    $x = (int) (($W - ($box[2] - $box[0])) / 2);
    imagettftext($img, $size, 0, $x, $y, $color, $font, $text);
};

$center(110, $fontBold, 'ESI', 250, $white);
$center(28, $fontBold, 'ESI JOURNAL', 330, $lightBlue);
$center(20, $fontRegular, 'OPEN ACCESS', 375, $muted);
$center(20, $fontRegular, 'PEER-REVIEWED', 410, $muted);
$center(18, $fontRegular, '[DRAFT COVER]', 700, $blue);
$center(16, $fontRegular, 'Replace with final design', 730, $muted);

imagepng($img, $output);
imagedestroy($img);
echo "Wrote $output\n";
