<?php
// SMTP check used by scripts/setup-email.sh (runs inside the OJS app container).
// Uses the same mail library as OJS 3.5 (Symfony Mailer). Never prints the password.
//
//   php smtp-test.php stdin   stdin lines: username, password, recipient   (server smtp.gmail.com:587)
//   php smtp-test.php live    server/username/password from config.inc.php; stdin line: recipient
// An empty recipient only checks the login and sends nothing.

require '/var/www/html/lib/pkp/lib/vendor/autoload.php';

use Symfony\Component\Mailer\Mailer;
use Symfony\Component\Mailer\Transport\Smtp\EsmtpTransport;
use Symfony\Component\Mime\Email;

$mode = $argv[1] ?? 'stdin';
$line = fn () => trim((string) fgets(STDIN));

if ($mode === 'live') {
    $c = parse_ini_file('/var/www/html/config.inc.php', true, INI_SCANNER_RAW);
    $e = $c['email'] ?? [];
    $get = fn ($k) => trim((string) ($e[$k] ?? ''), "\"' ");
    if ($get('default') !== 'smtp') {
        echo "FAILED: config.inc.php [email] default is not 'smtp'\n";
        exit(2);
    }
    [$host, $port, $enc, $user, $pass] =
        [$get('smtp_server'), (int) $get('smtp_port'), $get('smtp_auth'), $get('smtp_username'), $get('smtp_password')];
    $to = $line();
} else {
    [$user, $pass, $to] = [$line(), $line(), $line()];
    [$host, $port, $enc] = ['smtp.gmail.com', 587, 'tls'];
}

// 'ssl' = TLS from the first byte (port 465); otherwise STARTTLS is negotiated (port 587).
$transport = new EsmtpTransport($host, $port, $enc === 'ssl');
$transport->setUsername($user);
$transport->setPassword($pass);

try {
    $transport->start();
    echo "LOGIN OK ($user at $host:$port)\n";
    if ($to !== '') {
        $mail = (new Email())
            ->from($user)
            ->to($to)
            ->subject('OJS email test - ' . gethostname())
            ->text("This test message was sent by scripts/setup-email.sh on " . date('Y-m-d H:i T') . ".\n"
                . "If you can read it, the journal can send email.\n");
        (new Mailer($transport))->send($mail);
        echo "TEST EMAIL SENT to $to\n";
    }
    $transport->stop();
} catch (Throwable $ex) {
    $msg = preg_replace('/\s+/', ' ', $ex->getMessage());
    if ($pass !== '') {
        $msg = str_replace($pass, '<hidden>', $msg);
    }
    echo "FAILED: $msg\n";
    exit(1);
}
