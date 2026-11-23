<?php

declare(strict_types=1);

// PHP-CS-Fixer の設定: PER Coding Style 3.0 + PHP 8.5 向けの書き換え
return new PhpCsFixer\Config()
    ->setRules([
        '@PER-CS3x0' => true,
        '@PHP8x5Migration' => true,
    ])
    ->setFinder(PhpCsFixer\Finder::create()->in(__DIR__)->exclude('vendor'));
