<?php
/**
 * seeds/make-white-logo.php — derive a white ESI footer logo from the black one.
 *
 * Dark pixels become white; the blue accent is preserved; transparency kept.
 * Run inside the app container:
 *
 *   docker compose cp seeds/make-white-logo.php app:/tmp/make-white-logo.php
 *   docker compose exec -T app php /tmp/make-white-logo.php
 *   docker compose cp app:/tmp/esi_footer_white.png volumes/public/journals/1/esi_footer_white.png
 *
 * Then point the `pageFooter` journal setting at the new file.
 */
$src = '/var/www/html/public/journals/1/esi_footer_black.png';
$dst = '/tmp/esi_footer_white.png';
$im = imagecreatefrompng($src);
$w = imagesx($im); $h = imagesy($im);
$out = imagecreatetruecolor($w, $h);
imagesavealpha($out, true);
$transparent = imagecolorallocatealpha($out, 0, 0, 0, 127);
imagefill($out, 0, 0, $transparent);
$white = imagecolorallocate($out, 255, 255, 255);
for ($y = 0; $y < $h; $y++) {
    for ($x = 0; $x < $w; $x++) {
        $c = imagecolorat($im, $x, $y);
        $a = ($c >> 24) & 127;
        if ($a > 100) {
            continue; // transparent
        }
        $r = ($c >> 16) & 255; $g = ($c >> 8) & 255; $b = $c & 255;
        if ($r < 110 && $g < 110 && $b < 110) {
            imagesetpixel($out, $x, $y, $white);
            // restore original alpha on the white pixel
            $w2 = imagecolorallocatealpha($out, 255, 255, 255, $a);
            imagesetpixel($out, $x, $y, $w2);
        } else {
            $keep = imagecolorallocatealpha($out, $r, $g, $b, $a);
            imagesetpixel($out, $x, $y, $keep);
        }
    }
}
imagepng($out, $dst);
echo "Wrote $dst\n";
